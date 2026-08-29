# Vast GB10 hotfix

Fixes two issues observed on first real Vast.ai GB10 boot:

1. `/opt/vllm/serve-ds4-flash.sh: Permission denied`
   - The Mia serve script is now explicitly `chmod 0755` in the image.
2. False disk-space failure after successful model preparation
   - The wrapper now validates total allocated container storage, while treating remaining free space only as runtime/cache headroom.

The `No module named 'vllm._version'` line is a non-fatal runtime warning from this vLLM image; the subsequent GB10/NVFP4 self-test continuing successfully confirms it is not the startup failure.
