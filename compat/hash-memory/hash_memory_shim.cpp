// Android 17 libc++ exports std::__hash_memory; Android 16 keeps it inline.
// Stock system_ext blobs built against the newer toolchain reference it.
#include <functional>

_LIBCPP_BEGIN_NAMESPACE_STD
[[gnu::visibility("default")]] size_t __hash_memory(const void* __ptr, size_t __size) noexcept {
    return __murmur2_or_cityhash<size_t>()(__ptr, __size);
}
_LIBCPP_END_NAMESPACE_STD
