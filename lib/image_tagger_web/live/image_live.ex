defmodule ImageTaggerWeb.ImageLive do
  use ImageTaggerWeb, :live_view
  alias ImageTagger.ImageService

  @impl true
  def mount(_params, _session, socket) do
    images = ImageService.list_images()

    socket =
      socket
      |> assign(:images, images)
      |> assign(:filtered_images, images)
      |> assign(:current_image, List.first(images))
      |> assign(:search_term, "")
      |> assign(:show_tag_form, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    filtered_images = ImageService.filter_images_by_tags(socket.assigns.images, search_term)
    current_image = List.first(filtered_images) || socket.assigns.current_image

    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:filtered_images, filtered_images)
      |> assign(:current_image, current_image)

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_image", _params, socket) do
    next_image =
      ImageService.get_next_image(
        socket.assigns.filtered_images,
        socket.assigns.current_image.path
      )

    socket = assign(socket, :current_image, next_image || socket.assigns.current_image)
    {:noreply, socket}
  end

  @impl true
  def handle_event("previous_image", _params, socket) do
    prev_image =
      ImageService.get_previous_image(
        socket.assigns.filtered_images,
        socket.assigns.current_image.path
      )

    socket = assign(socket, :current_image, prev_image || socket.assigns.current_image)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_tag_form", _params, socket) do
    socket = assign(socket, :show_tag_form, !socket.assigns.show_tag_form)
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_tags", %{"tags" => new_tags}, socket) do
    current_image = socket.assigns.current_image

    case ImageService.add_tags_to_image(current_image.path, String.trim(new_tags)) do
      {:ok, new_path} ->
        # Refresh images and update current image
        images = ImageService.list_images()
        updated_image = ImageService.get_image_by_path(images, new_path)
        filtered_images = ImageService.filter_images_by_tags(images, socket.assigns.search_term)

        socket =
          socket
          |> assign(:images, images)
          |> assign(:filtered_images, filtered_images)
          |> assign(:current_image, updated_image)
          |> assign(:show_tag_form, false)

        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "Failed to add tag")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    current_image = socket.assigns.current_image

    case ImageService.remove_tag_from_image(current_image.path, tag) do
      {:ok, new_path} ->
        # Refresh images and update current image
        images = ImageService.list_images()
        updated_image = ImageService.get_image_by_path(images, new_path)
        filtered_images = ImageService.filter_images_by_tags(images, socket.assigns.search_term)

        socket =
          socket
          |> assign(:images, images)
          |> assign(:filtered_images, filtered_images)
          |> assign(:current_image, updated_image)

        {:noreply, socket}

      {:error, _reason} ->
        socket = put_flash(socket, :error, "Failed to remove tag")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_image", %{"path" => path}, socket) do
    selected_image = ImageService.get_image_by_path(socket.assigns.filtered_images, path)
    socket = assign(socket, :current_image, selected_image || socket.assigns.current_image)
    {:noreply, socket}
  end
end
