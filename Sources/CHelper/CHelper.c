//
//  CHelper.c
//  
//
//  Created by iMoe Nya on 2024/3/21.
//

#include "CHelper.h"
#include <stdio.h>
#include <dlfcn.h>

void* _performMethod(const char* stringMethod, const void* onObject) {
    void* (*functionImplementation)(void*);
    *(void **) (&functionImplementation) = dlsym(RTLD_DEFAULT, stringMethod);

    char *error;

    if ((error = dlerror()) != NULL)  {
        printf("CHelper: method not found\n");
    } else {
        return functionImplementation(onObject);
    }
    return NULL;
}
