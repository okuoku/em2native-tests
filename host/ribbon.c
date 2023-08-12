#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>

#include "c-proto.h"

void*
BsFileOpenForRead(const char* path){
    return (void*)fopen(path, "rb");
}

void*
BsFileOpenForReadWrite(const char* path){
    return (void*)fopen(path, "w+b");
}

void*
BsFileReadAll(const char* path){
    FILE* fp;
    size_t binsize, readsize;
    void* out;

    fp = fopen(path, "rb");

    /* FIXME: This isn't portable */
    fseek(fp, 0, SEEK_END);
    binsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    out = malloc(binsize);
    if(! out){
        abort();
    }

    readsize = fread(out, 1, binsize, fp);
    if(readsize != binsize){
        abort();
    }
    fclose(fp);
    return out;
}

void
BsFileClose(void* handle){
    FILE* fp = (FILE*)handle;
    fclose(fp);
}

int
BsFileRead(void* handle, void* buf, size_t buflen, size_t* outlen){
    FILE* fp = (FILE*)handle;
    size_t readlen;

    readlen = fread(buf, 1, buflen, fp);
    *outlen = readlen;
    return 0;
}

int
BsFileWrite(void* handle, void* buf, size_t buflen, size_t* outlen){
    FILE* fp = (FILE*)handle;
    size_t writelen;
    writelen = fwrite(buf, 1, buflen, fp);
    *outlen = writelen;
    return 0;
}

void
BsFileFlush(void* handle){
    FILE* fp = (FILE*)handle;
    fflush(fp);
}

void*
BsFileGetStdin(void){
    return (void*)stdin;
}

void*
BsFileGetStdout(void){
    return (void*)stdout;
}

void*
BsFileGetStderr(void){
    return (void*)stderr;
}

void
BsDebugPrintf(const char* fmt, ...){
    va_list ap;
    va_start(ap, fmt);
    (void)vfprintf(stderr, fmt, ap);
    va_end(ap);
}

/* main */
static const char* bootfile = BUILDROOT "/dump.bin";

int
main(int ac, char** av){
    int i,argstart;
    uint8_t* bootstrap;
    Value str;

    RnCtx ctx;
    RnCtxInit(&ctx);

    RnValueLink(&ctx, &str);
    /* Parse arguments */
    if(ac > 0){
        argstart = 1; // TEMP
        RnVector(&ctx, &ctx.args, ac - argstart + 4);
        /* default arguments */
        RnString(&ctx, &str, "-yuniroot", sizeof("-yuniroot") - 1);
        RnVectorSet(&ctx, &ctx.args, &str, 0);
        RnString(&ctx, &str, YUNIROOT, sizeof(YUNIROOT) - 1);
        RnVectorSet(&ctx, &ctx.args, &str, 1);
        RnString(&ctx, &str, "-runtimeroot", sizeof("-runtimeroot") - 1);
        RnVectorSet(&ctx, &ctx.args, &str, 2);
        RnString(&ctx, &str, RUNTIMEROOT, sizeof(RUNTIMEROOT) - 1);
        RnVectorSet(&ctx, &ctx.args, &str, 3);
        for(i=argstart;i!=ac;i++){
            /* pack rest arguments into a vector */
            // FIXME: Use ARG_MAX on posix
            RnString(&ctx, &str, av[i], strnlen(av[i], 4096));
            RnVectorSet(&ctx, &ctx.args, &str, i - argstart + 4);
        }
    }else{
        /* AC should never be 0 on POSIX */
        abort();
    }
    RnValueUnlink(&ctx, &str);

    /* Load bootfile */
    bootstrap = (uint8_t*)BsFileReadAll(bootfile);

    /* Run bootstrap */
    RnCtxRunBootstrap(&ctx, bootstrap);

    free(bootstrap);
    // FIXME: Deinit context here

    return 0;
}

