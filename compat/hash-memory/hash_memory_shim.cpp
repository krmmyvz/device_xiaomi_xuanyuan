// Android 17 libc++ exports std::__hash_memory itself, so the stock system_ext blobs
// resolve it from libc++.so. The module stays (as an empty library) so existing
// shared_libs references keep working; defining the symbol here would conflict with
// the declaration in <functional>.
