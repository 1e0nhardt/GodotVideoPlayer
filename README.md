# GodotVideoPlayer
Godot 简易视频播放器

## 编译FFmpeg
使用msys2编译

cd /d/Games/Godot/Extensions/GodotVideoPlayer/gd_extensions/gozen/ffmpeg
./configure --prefix=../ffmpeg_bin --enable-gpl --enable-shared
make -j 16
make install

## windows下运行准备
1. 将编译好的libgozen.dll复制到GodotVideoPlayer/src/bin目录下
2. 将ffmpeg_bin/bin目录下的dll文件复制到GodotVideoPlayer/src/bin目录下
3. 将msys64/mingw64/bin目录下的部分dll文件复制到GodotVideoPlayer/src/bin目录下
    - libbz2-1.dll
    - libiconv-2.dll
    - liblzma-5.dll
    - libwinpthread-1.dll
    - zlib-1.dll
