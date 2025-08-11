defmodule ImageTaggerWeb.ProjectComponents do
  use Phoenix.Component

  import ImageTaggerWeb.CoreComponents, only: [icon: 1]

  slot :title
  slot :inner_block

  def header_bar(assigns) do
    ~H"""
    <header class="bg-gray-800 shadow-lg border-b border-gray-700">
      <div class="max-w-7xl mx-auto px-4">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold text-blue-400">{render_slot(@title)}</h1>
          <div class="max-w-7xl mx-auto px-4 py-2">
            <div class="flex items-center justify-between">
              {render_slot(@inner_block)}
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  attr :search_term, :string, doc: "The term(s) currently searched"
  attr :rest, :global, include: ~w(phx-change phx-submit)

  def search_bar(assigns) do
    ~H"""
    <form phx-change="search" phx-submit="search" class="flex-1 max-w-md mx-8">
      <input
        type="text"
        name="search"
        value={@search_term}
        placeholder="Search by tags..."
        class="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-white placeholder-gray-400"
      />
    </form>
    """
  end

  attr :quantity, :integer, required: true, doc: "The total number of images"

  def image_counter(assigns) do
    ~H"""
    <div class="text-sm text-gray-400">
      {@quantity} images
    </div>
    """
  end

  attr :images, :list, doc: "The images currently available"
  attr :current_image, :map, doc: "The currently viewed image"

  def sidebar(assigns) do
    ~H"""
    <div class="w-fit max-w-48 bg-gray-800 border-r border-gray-700 overflow-y-auto">
      <div class="p-2">
        <h2 class="text-lg font-semibold mb-4 text-gray-300">Images</h2>
        <div class="space-y-2">
          <div
            :for={image <- @images}
            class={"p-3 rounded-lg cursor-pointer transition-colors #{if @current_image && @current_image.path == image.path, do: "bg-blue-600", else: "bg-gray-700 hover:bg-gray-600"}"}
            phx-click="select_image"
            phx-value-path={image.path}
          >
            <div class="text-sm font-medium truncate">{image.name}</div>
            <div class="text-xs text-gray-400 mt-1">
              {format_file_size(image.size)}
            </div>
            <div :if={length(image.tags) > 0} class="flex flex-wrap gap-1 mt-2">
              <span :for={tag <- image.tags} class="px-2 py-1 bg-blue-500 text-xs rounded-full">
                #{tag}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :image, :map, required: true, doc: "The image to display"

  attr :on_next, :string,
    required: true,
    doc: "The liveview event name to trigger when the next-button is clicked"

  attr :on_prev, :string,
    required: true,
    doc: "The event to send when the prev-button is clicked"

  def image_display(assigns) do
    ~H"""
    <div class="relative flex-1 flex flex-col items-center justify-center bg-black h-2/3">
      <img
        src={"data:image/jpeg;base64,#{Base.encode64(File.read!(@image.path))}"}
        alt={@image.name}
        class="h-full w-full object-scale-down"
      />
      <.nav_button phx-click={@on_prev} class="absolute left-4 top-1/2">
        <.icon name="hero-chevron-left-solid" class="w-6 h-6" />
      </.nav_button>
      <.nav_button phx-click={@on_next} class="absolute right-4 top-1/2">
        <.icon name="hero-chevron-right-solid" class="w-6 h-6" />
      </.nav_button>
    </div>
    """
  end

  attr :class, :string
  attr :rest, :global, include: ~w(phx-click)
  slot :inner_block

  defp nav_button(assigns) do
    ~H"""
    <button
      class={[
        @class,
        "transform -translate-y-1/2 bg-black bg-opacity-50 hover:bg-opacity-75 text-white p-3 rounded-full transition-all"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  slot :inner_block

  def image_info(assigns) do
    ~H"""
    <div class="bg-gray-800 border-t border-gray-700 pl-6">
      <div class="max-w-7xl mx-auto">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :tags, :list, required: true, doc: "The tags of the image currently displayed"

  attr :on_toggle_tag_form, :string,
    required: true,
    doc: "The event to send when the tag form is toggled"

  attr :show_tag_form, :boolean,
    required: true,
    doc: "Defines whether the tag form should be displayed"

  attr :on_remove_tag, :string, required: true, doc: "The event to send when a tag is removed"
  attr :on_add_tags, :string, required: true, doc: "The event to send when tags are added"

  def tags_section(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mb-3">
      <.toggle_tag_form_button :if={!@show_tag_form} phx-click={@on_toggle_tag_form} />
      <.tag_form :if={@show_tag_form} phx-submit={@on_add_tags} on_cancel={@on_toggle_tag_form} />
      <.existing_tags tags={@tags} />
    </div>
    """
  end

  attr :rest, :global, include: ~w(phx-click)

  defp toggle_tag_form_button(assigns) do
    ~H"""
    <button
      class="w-24 px-3 py-1 bg-blue-600 hover:bg-blue-700 text-white text-sm rounded-md transition-colors"
      {@rest}
    >
      Add Tags
    </button>
    """
  end

  attr :tags, :list

  defp existing_tags(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2">
      <div :for={tag <- @tags} class="flex items-center gap-2 px-3 py-1 bg-blue-600 rounded-full">
        <span class="text-sm">#{tag}</span>
        <button phx-click="remove_tag" phx-value-tag={tag} class="text-blue-200 hover:text-white">
          <.icon name="hero-x-mark-solid" class="w-4 h-4" />
        </button>
      </div>

      <span :if={length(@tags) == 0} class="text-gray-500 text-sm">No tags</span>
    </div>
    """
  end

  attr :on_cancel, :string
  attr :rest, :global, include: ~w(phx-submit)

  defp tag_form(assigns) do
    ~H"""
    <form class="flex gap-2" {@rest}>
      <input
        type="text"
        name="tags"
        placeholder="Enter tags separated by empty space"
        class="px-3 py-1 bg-gray-700 border border-gray-600 rounded-md text-sm text-white placeholder-gray-400 min-w-72"
        required
      />
      <button
        type="submit"
        class="px-2 py-1 bg-green-600 hover:bg-green-700 text-white text-sm rounded-md transition-colors"
      >
        Add
      </button>
      <button
        type="button"
        phx-click={@on_cancel}
        class="px-2 py-1 bg-gray-600 hover:bg-gray-700 text-white text-sm rounded-md transition-colors"
      >
        Cancel
      </button>
    </form>
    """
  end

  slot :header
  slot :message

  def no_image_info(assigns) do
    ~H"""
    <div class="flex-1 flex items-center justify-center">
      <div class="text-center text-gray-400">
        <.icon name="hero-photo-solid" class="w-16 h-16 mx-auto mb-4" />
        <h2 class="text-xl font-semibold mb-2">{render_slot(@header)}</h2>
        <p>
          {render_slot(@message)}
        </p>
      </div>
    </div>
    """
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end
