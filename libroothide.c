// Stub libroothide.dylib for Dopamine jailbreak
// Provides _jbroot function that roothide-built binaries need

#include <string.h>

// jbroot on roothide translates paths - on Dopamine just return unchanged
__attribute__((visibility("default")))
const char* jbroot(const char* path) {
    return path;
}

// Some binaries call _jbroot directly
__attribute__((visibility("default")))
const char* _jbroot(const char* path) {
    return path;
}
