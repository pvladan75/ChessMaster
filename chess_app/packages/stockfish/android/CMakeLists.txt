cmake_minimum_required(VERSION 3.4.1)

# Enable 16KB page size support for Android (required for Google Play)
add_link_options(-Wl,-z,max-page-size=16384)
add_link_options(-Wl,-z,common-page-size=16384)

file(GLOB_RECURSE cppPaths "../ios/Stockfish/src/*.cpp")
# Stockfish 19's universal/ holds the entry points of its multi-arch release
# binaries (one main per CPU slice, and a second copy of the network). Upstream
# compiles them only for the *-universal targets, never for plain armv8.
list(FILTER cppPaths EXCLUDE REGEX "/universal/")
add_library(
  stockfish
  SHARED
  ../ios/FlutterStockfish/ffi.cpp
  ${cppPaths}
)

if(ANDROID_ABI STREQUAL arm64-v8a)
  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(stockfish PRIVATE -DUSE_PTHREADS -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8)
  else()
    target_compile_options(stockfish PRIVATE -fno-exceptions -DUSE_PTHREADS -DNDEBUG -O3 -DIS_64BIT -DUSE_POPCNT -DUSE_NEON=8)
  endif()
else()
  if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(stockfish PRIVATE -DUSE_PTHREADS)
  else()
    target_compile_options(stockfish PRIVATE -fno-exceptions -DUSE_PTHREADS -DNDEBUG -O3)
  endif()
endif()

# Stockfish 19 has one network (EvalFileDefaultName in src/evaluate.h); the
# big/small pair of 16.1-18 is gone. The hash is the file's own SHA-256 prefix,
# so a truncated or substituted download fails the build instead of embedding.
file(DOWNLOAD https://tests.stockfishchess.org/api/nn/nn-1a298aa575a0.nnue ${CMAKE_BINARY_DIR}/nn-1a298aa575a0.nnue
  EXPECTED_HASH SHA256=1a298aa575a085434d29027978dc36867fe9c5bcea9376654b7a8eba1e52dfc2)
