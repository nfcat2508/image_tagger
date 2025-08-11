defmodule ImageTagger.ImageService do
  @moduledoc """
  Service for managing images and their tags.
  """

  @supported_extensions [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]

  def list_images do
    Application.get_env(:image_tagger, :image_directories, [])
    |> Enum.flat_map(&scan_directory/1)
    |> Enum.filter(&image_file?/1)
    |> Enum.map(&build_image_info/1)
    |> Enum.sort_by(& &1.name)
  end

  def filter_images_by_tags(images, search_term) when search_term == "" or is_nil(search_term) do
    images
  end

  def filter_images_by_tags(images, search_term) do
    search_tags =
      search_term
      |> String.downcase()
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    Enum.filter(images, fn image ->
      image_tags = Enum.map(image.tags, &String.downcase/1)

      Enum.any?(search_tags, fn tag ->
        Enum.any?(image_tags, &String.contains?(&1, tag))
      end)
    end)
  end

  def add_tags_to_image(image_path, new_tags_string) do
    current_tags = extract_tags_from_filename(image_path)

    new_tags =
      new_tags_string
      |> String.split()
      |> Enum.filter(&(&1 not in current_tags))
      |> Enum.reduce(current_tags, fn tag, current -> [tag | current] end)

    if new_tags != current_tags do
      update_filename_with_tags(image_path, new_tags)
    else
      {:ok, image_path}
    end
  end

  def remove_tag_from_image(image_path, tag_to_remove) do
    current_tags = extract_tags_from_filename(image_path)
    new_tags = Enum.reject(current_tags, &(&1 == tag_to_remove))
    update_filename_with_tags(image_path, new_tags)
  end

  def get_image_by_path(images, path) do
    Enum.find(images, &(&1.path == path))
  end

  def get_next_image(images, current_path) do
    current_index = Enum.find_index(images, &(&1.path == current_path))

    case current_index do
      nil -> nil
      index when index == length(images) - 1 -> Enum.at(images, 0)
      index -> Enum.at(images, index + 1)
    end
  end

  def get_previous_image(images, current_path) do
    current_index = Enum.find_index(images, &(&1.path == current_path))

    case current_index do
      nil -> nil
      0 -> Enum.at(images, -1)
      index -> Enum.at(images, index - 1)
    end
  end

  defp scan_directory(directory) do
    case File.exists?(directory) do
      true ->
        directory
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)

      false ->
        []
    end
  end

  defp image_file?(path) do
    extension = Path.extname(path) |> String.downcase()
    extension in @supported_extensions
  end

  defp build_image_info(path) do
    filename = Path.basename(path)
    {base_name, tags} = parse_filename_and_tags(filename)

    %{
      path: path,
      name: base_name,
      filename: filename,
      tags: tags,
      size: get_file_size(path)
    }
  end

  defp parse_filename_and_tags(filename) do
    [base_name | tag_parts] = String.split(filename, "#")

    {tags, extension} = extract_tags_and_extension(tag_parts)

    {String.trim(base_name) <> extension, tags}
  end

  defp extract_tags_and_extension(parts) do
    {tags, extension} = Enum.reduce(parts, {[], ""}, &update_tags_and_extension/2)
    # retain original order of tags in filename
    {Enum.reverse(tags), extension}
  end

  defp update_tags_and_extension(part, {tags, extension}) do
    case String.split(part, ".", parts: 2) do
      [tag] -> {[String.trim(tag) | tags], extension}
      [tag, ext] -> {[String.trim(tag) | tags], ".#{ext}"}
    end
  end

  defp extract_tags_from_filename(path) do
    filename = Path.basename(path)
    {_base_name, tags} = parse_filename_and_tags(filename)
    tags
  end

  defp update_filename_with_tags(current_path, new_tags) do
    directory = Path.dirname(current_path)
    current_filename = Path.basename(current_path)
    {base_name, _old_tags} = parse_filename_and_tags(current_filename)

    extension = Path.extname(base_name)
    name_without_ext = Path.rootname(base_name)

    tag_suffix =
      case new_tags do
        [] -> ""
        tags -> "#" <> Enum.join(tags, "#")
      end

    new_filename = name_without_ext <> tag_suffix <> extension
    new_path = Path.join(directory, new_filename)

    case File.rename(current_path, new_path) do
      :ok -> {:ok, new_path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end
end
