defmodule ImageTagger.ImageServiceTest do
  use ExUnit.Case
  alias ImageTagger.ImageService

  @test_dir "test/fixtures/images"
  @test_images [
    "photo1.jpg",
    "photo2#nature.png",
    "photo3#nature#landscape.jpg",
    "photo4#portrait#family.jpeg",
    # Non-image file
    "document.pdf",
    "photo5#sunset#beach#vacation.webp"
  ]

  setup do
    # Create test directory and files
    File.mkdir_p!(@test_dir)

    Enum.each(@test_images, fn filename ->
      path = Path.join(@test_dir, filename)
      File.write!(path, "fake_image_content")
    end)

    # Set test directories in application config
    original_dirs = Application.get_env(:image_tagger, :image_directories, [])
    Application.put_env(:image_tagger, :image_directories, [@test_dir])

    on_exit(fn ->
      File.rm_rf!(@test_dir)
      Application.put_env(:image_tagger, :image_directories, original_dirs)
    end)

    :ok
  end

  describe "list_images/0" do
    test "returns list of image files with correct structure" do
      images = ImageService.list_images()

      assert length(images) == 5

      first_image = List.first(images)
      assert Map.has_key?(first_image, :path)
      assert Map.has_key?(first_image, :name)
      assert Map.has_key?(first_image, :filename)
      assert Map.has_key?(first_image, :tags)
      assert Map.has_key?(first_image, :size)
    end

    test "correctly parses filenames and tags" do
      images = ImageService.list_images()

      no_tags_image = Enum.find(images, &(&1.filename == "photo1.jpg"))
      assert no_tags_image.name == "photo1.jpg"
      assert no_tags_image.tags == []

      single_tag_image = Enum.find(images, &(&1.filename == "photo2#nature.png"))
      assert single_tag_image.name == "photo2.png"
      assert single_tag_image.tags == ["nature"]

      multi_tag_image = Enum.find(images, &(&1.filename == "photo3#nature#landscape.jpg"))
      assert multi_tag_image.name == "photo3.jpg"
      assert multi_tag_image.tags == ["nature", "landscape"]

      many_tags_image = Enum.find(images, &(&1.filename == "photo5#sunset#beach#vacation.webp"))
      assert many_tags_image.name == "photo5.webp"
      assert many_tags_image.tags == ["sunset", "beach", "vacation"]
    end

    test "excludes non-image files" do
      images = ImageService.list_images()
      pdf_image = Enum.find(images, &String.contains?(&1.filename, "document.pdf"))
      assert is_nil(pdf_image)
    end

    test "returns images sorted by name" do
      images = ImageService.list_images()
      names = Enum.map(images, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "filter_images_by_tags/2" do
    setup do
      images = ImageService.list_images()
      {:ok, images: images}
    end

    test "returns all images for empty search term", %{images: images} do
      filtered = ImageService.filter_images_by_tags(images, "")
      assert length(filtered) == length(images)

      filtered_nil = ImageService.filter_images_by_tags(images, nil)
      assert length(filtered_nil) == length(images)
    end

    test "filters images by single tag", %{images: images} do
      filtered = ImageService.filter_images_by_tags(images, "nature")
      assert length(filtered) == 2

      filenames = Enum.map(filtered, & &1.filename)
      assert "photo2#nature.png" in filenames
      assert "photo3#nature#landscape.jpg" in filenames
    end

    test "filters images having at least one of the provided tags", %{images: images} do
      filtered = ImageService.filter_images_by_tags(images, "sunset portrait")

      assert length(filtered) == 2
    end

    test "search is case insensitive", %{images: images} do
      filtered_lower = ImageService.filter_images_by_tags(images, "nature")
      filtered_upper = ImageService.filter_images_by_tags(images, "NATURE")
      filtered_mixed = ImageService.filter_images_by_tags(images, "NaTuRe")

      assert length(filtered_lower) == length(filtered_upper)
      assert length(filtered_lower) == length(filtered_mixed)
    end

    test "supports partial tag matching", %{images: images} do
      filtered = ImageService.filter_images_by_tags(images, "port")

      assert length(filtered) == 1
      portrait_image = List.first(filtered)
      assert "portrait" in portrait_image.tags
    end
  end

  describe "add_tags_to_image/2" do
    setup do
      test_file = Path.join(@test_dir, "test_image.jpg")
      File.write!(test_file, "test_content")
      {:ok, test_file: test_file}
    end

    test "adds new tag to image without existing tags", %{test_file: test_file} do
      {:ok, new_path} = ImageService.add_tags_to_image(test_file, "newtag")

      assert Path.basename(new_path) == "test_image#newtag.jpg"
      assert File.exists?(new_path)
      refute File.exists?(test_file)
    end

    test "adds tag to image with existing tags", %{test_file: test_file} do
      {:ok, tagged_path} = ImageService.add_tags_to_image(test_file, "first")

      {:ok, final_path} = ImageService.add_tags_to_image(tagged_path, "second")

      assert Path.basename(final_path) == "test_image#second#first.jpg"
      assert File.exists?(final_path)
    end

    test "does not add duplicate tags", %{test_file: test_file} do
      {:ok, path1} = ImageService.add_tags_to_image(test_file, "duplicate")
      {:ok, path2} = ImageService.add_tags_to_image(path1, "duplicate")

      assert path1 == path2
      assert Path.basename(path2) == "test_image#duplicate.jpg"
    end

    test "adds multiple tags when string provided with space between tags", %{
      test_file: test_file
    } do
      {:ok, new_path} = ImageService.add_tags_to_image(test_file, "newtag nexttag")

      assert Path.basename(new_path) == "test_image#nexttag#newtag.jpg"
      assert File.exists?(new_path)
      refute File.exists?(test_file)
    end

    test "adds multiple tags when string provided with arbitrary space between tags", %{
      test_file: test_file
    } do
      {:ok, new_path} = ImageService.add_tags_to_image(test_file, "newtag   nexttag")

      assert Path.basename(new_path) == "test_image#nexttag#newtag.jpg"
      assert File.exists?(new_path)
      refute File.exists?(test_file)
    end
  end

  describe "remove_tag_from_image/2" do
    setup do
      test_file = Path.join(@test_dir, "test_image#tag1#tag2#tag3.jpg")
      File.write!(test_file, "test_content")
      {:ok, test_file: test_file}
    end

    test "removes specified tag from image", %{test_file: test_file} do
      {:ok, new_path} = ImageService.remove_tag_from_image(test_file, "tag2")

      assert Path.basename(new_path) == "test_image#tag1#tag3.jpg"
      assert File.exists?(new_path)
      refute File.exists?(test_file)
    end

    test "removes all tags when removing the last tag" do
      single_tag_file = Path.join(@test_dir, "single#onlytag.jpg")
      File.write!(single_tag_file, "test_content")

      {:ok, new_path} = ImageService.remove_tag_from_image(single_tag_file, "onlytag")

      assert Path.basename(new_path) == "single.jpg"
      assert File.exists?(new_path)
    end
  end

  describe "get_image_by_path/2" do
    setup do
      images = ImageService.list_images()
      {:ok, images: images}
    end

    test "finds image by exact path match", %{images: images} do
      first_image = List.first(images)
      found_image = ImageService.get_image_by_path(images, first_image.path)

      assert found_image == first_image
    end

    test "returns nil for non-existent path", %{images: images} do
      found_image = ImageService.get_image_by_path(images, "/non/existent/path.jpg")

      assert is_nil(found_image)
    end
  end

  describe "get_next_image/2" do
    setup do
      images = ImageService.list_images()
      {:ok, images: images}
    end

    test "returns next image in sequence", %{images: images} do
      first_image = List.first(images)
      second_image = Enum.at(images, 1)

      next_image = ImageService.get_next_image(images, first_image.path)
      assert next_image == second_image
    end

    test "wraps around to first image when at end", %{images: images} do
      last_image = List.last(images)
      first_image = List.first(images)

      next_image = ImageService.get_next_image(images, last_image.path)
      assert next_image == first_image
    end

    test "returns nil for non-existent image", %{images: images} do
      next_image = ImageService.get_next_image(images, "/non/existent.jpg")
      assert is_nil(next_image)
    end
  end

  describe "get_previous_image/2" do
    setup do
      images = ImageService.list_images()
      {:ok, images: images}
    end

    test "returns previous image in sequence", %{images: images} do
      second_image = Enum.at(images, 1)
      first_image = List.first(images)

      prev_image = ImageService.get_previous_image(images, second_image.path)
      assert prev_image == first_image
    end

    test "wraps around to last image when at beginning", %{images: images} do
      first_image = List.first(images)
      last_image = List.last(images)

      prev_image = ImageService.get_previous_image(images, first_image.path)
      assert prev_image == last_image
    end

    test "returns nil for non-existent image", %{images: images} do
      prev_image = ImageService.get_previous_image(images, "/non/existent.jpg")
      assert is_nil(prev_image)
    end
  end
end
