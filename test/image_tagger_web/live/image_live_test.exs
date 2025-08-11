defmodule ImageTaggerWeb.ImageLiveTest do
  use ImageTaggerWeb.ConnCase
  import Phoenix.LiveViewTest

  @test_dir "test/live_fixtures/images"
  @test_images [
    "photo1.jpg",
    "photo2#nature.png",
    "photo3#nature#landscape.jpg",
    "photo4#portrait#family.jpeg"
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

  describe "mount" do
    test "successfully loads with images", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Image Tagger"

      assert html =~ "4 images"
      assert html =~ "photo1.jpg"
      assert html =~ "photo2#nature.png"
      assert html =~ "photo3#nature#landscape.jpg"
      assert html =~ "photo4#portrait#family.jpeg"
    end
  end

  describe "search functionality" do
    test "filters images by tag search", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = search_for_tags(view, "nature")

      assert html =~ "2 images"
      assert html =~ "photo2#nature.png"
      assert html =~ "photo3#nature#landscape.jpg"
      refute html =~ "photo1.jpg"
    end

    test "shows all images when search is cleared", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # First search for something
      search_for_tags(view, "nature")

      # Then clear search
      html = search_for_tags(view, "")

      assert html =~ "4 images"
    end

    test "search is case insensitive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = search_for_tags(view, "NATURE")

      assert html =~ "2 images"
      assert html =~ "photo2#nature.png"
    end
  end

  describe "image navigation" do
    test "navigates to next image", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      initial_image = current_image_name(html)

      html = click_next_image_button(view)
      next_image = current_image_name(html)

      assert next_image != initial_image
    end

    test "navigates to previous image", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = click_next_image_button(view)
      next_image = current_image_name(html)

      html = click_prev_image_button(view)
      prev_image = current_image_name(html)

      assert prev_image != next_image
    end

    test "wraps around at end of image list", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      initial_image = current_image_name(html)

      # Click next 4 times (should wrap around)
      html =
        Enum.reduce(1..4, html, fn _, _html ->
          click_next_image_button(view)
        end)

      final_image = current_image_name(html)
      assert final_image == initial_image
    end
  end

  describe "sidebar behavior" do
    test "selects specific image from sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = select_img_in_sidebar(view, "photo2#nature.png")
      assert current_image_name(html) == "photo2.png"

      html = select_img_in_sidebar(view, "photo3#nature#landscape.jpg")
      assert current_image_name(html) == "photo3.jpg"
    end

    test "shows tags in sidebar for tagged images", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~r(phx-value-path.*#nature)
      assert html =~ ~r(phx-value-path.*#landscape)
      assert html =~ ~r(phx-value-path.*#portrait)
      assert html =~ ~r(phx-value-path.*#family)
    end

    test "displays file sizes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # our test files are small, so we only expect byte size here
      assert html =~ "B"
    end
  end

  describe "tag management" do
    test "shows add tags form when button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = click_add_tags_button(view)

      assert html =~ "Enter tags"
      assert html =~ "Cancel"
    end

    test "hides tags form when cancel clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      click_add_tags_button(view)

      html = click_cancel_tags_button(view)

      refute html =~ "Enter tag names"
    end

    test "adds new tag to current image", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      no_tag_image = "photo1.jpg"

      select_img_in_sidebar(view, no_tag_image)
      click_add_tags_button(view)

      html = add_tags(view, "newtag")

      assert html =~ "photo1#newtag.jpg"
    end

    test "removes tag from current image", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      tagged_image = "photo4#portrait#family.jpeg"

      select_img_in_sidebar(view, tagged_image)

      html = remove_tag(view, "portrait")

      refute html =~ "#portrait"
    end
  end

  describe "error handling" do
    test "handles no images gracefully", %{conn: conn} do
      File.rm_rf!(@test_dir)
      File.mkdir_p!(@test_dir)

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "No Images Found"
      assert html =~ "0 images"
    end
  end

  defp search_for_tags(view, search_input) do
    view
    |> form("form", %{search: search_input})
    |> render_change()
  end

  defp click_next_image_button(view) do
    view
    |> element(~s{button[phx-click="next_image"]})
    |> render_click()
  end

  defp click_prev_image_button(view) do
    view
    |> element(~s{button[phx-click="previous_image"]})
    |> render_click()
  end

  defp select_img_in_sidebar(view, img_name) do
    view
    |> element("[phx-value-path='#{path(img_name)}']")
    |> render_click()
  end

  defp click_add_tags_button(view) do
    view
    |> element("button", "Add Tags")
    |> render_click()
  end

  defp click_cancel_tags_button(view) do
    view
    |> element("button", "Cancel")
    |> render_click()
  end

  defp add_tags(view, tags_string) do
    view
    |> form(~s{form[phx-submit="add_tags"]}, %{tags: tags_string})
    |> render_submit()
  end

  defp remove_tag(view, tag) do
    view
    |> element("button[phx-value-tag='#{tag}']")
    |> render_click()
  end

  defp path(filename) do
    "#{@test_dir}/#{filename}"
  end

  defp current_image_name(html) do
    [[image_name]] =
      Regex.scan(~r/img.*alt="(.*)" class/, html, capture: :all_but_first)

    image_name
  end
end
