# Bash snippets

## CMAKE

### Build and install system wide

```
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -S . -B ./build
cmake --build ./build
sudo cmake --install ./build
```
