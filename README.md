## Getting started

You can run the project locally with the following steps:

1. Copy this repo via `git clone` or by downloading it
2. Run the `mix setup` Mix task from within the projects directory
3. Run the `IMAGE_DIRECTORIES=/path/to/your/image/directory mix phx.server` Mix task from within the projects directory
4. Open http://localhost:4000


```bash
git clone https://github.com/nfcat2508/image_tagger.git
cd image_tagger
mix setup
IMAGE_DIRECTORIES=~/Pictures/animals/cats mix phx.server
```

## About the app
* a desktop app where users can edit image file names inside the directories specified by their IMAGE_DIRECTORIES environment variable
* images can be searched by tag
* tags can be added/removed to/from images
* tags are appended as '#tagname' to the image file name (e.g. photo5#cat#cute#funny.webp)

## About the used technologies
* Phoenix LiveView
* installable as a PWA
