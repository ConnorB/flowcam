# Changelog

## flowcam 0.1.0

### Initial release

- Query USGS NIMS API camera metadata with
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  and
  [`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md).
- List available images for a camera with
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md).
- Build and retrieve timelapse image URLs with
  [`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md)
  and
  [`get_timelapse_url()`](https://connorb.github.io/flowcam/reference/get_timelapse_url.md).
- Download images to disk with
  [`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md).
- Assemble animated GIFs from downloaded frames with
  [`make_gif()`](https://connorb.github.io/flowcam/reference/make_gif.md).
- Assemble MP4 videos from downloaded frames with
  [`make_video()`](https://connorb.github.io/flowcam/reference/make_video.md)
  (requires the `av` package).
- API key management via
  [`set_nims_key()`](https://connorb.github.io/flowcam/reference/set_nims_key.md)
  and the `API_USGS_PAT` environment variable.
