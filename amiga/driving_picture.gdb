# Capture the geometry of the first large PICT drawn after leaving the garage.
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_picture.gdb ./diag_run.sh 20
set pagination off
set confirm off

break drawPackedPictureBits if size > 50000
commands
  silent
  set $payload = offset
  disable 1
  enable 2
  continue
end

break MacLoader.cpp:1370
disable 2
commands
  silent
  printf "\n===== DRIVING PICTURE =====\n"
  printf "PICT bytes = %u, decoded offset = %u\n", size, offset
  printf "picture frame: "
  x/4hd pictureFrame
  printf "target rect: "
  x/4hd targetRect
  printf "source PixMap header (rowBytes,bounds through pixelSize):\n"
  x/16hx picture+$payload
  printf "raster source, destination, mode:\n"
  x/9hd picture+offset-18
  printf "===========================\n\n"
  detach
  quit
end

continue
