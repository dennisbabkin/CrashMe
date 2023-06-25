//
//  Crash.hpp
//  CrashMe
//
//  Created by dennisbabkin.com on 6/25/23.
//
//  This project is a part of the blog post.
//  For more details, check:
//
//      https://dennisbabkin.com/blog/?i=AAA11600
//
//  This class attempts to crash this process in various ways
//


#ifndef Crash_hpp
#define Crash_hpp

#include <stdio.h>

#include <iostream>
#include <new>
#include <assert.h>



enum CRASH_TYPE
{
    CT_Unknown,
    
    CT_IllegalRead,
    CT_IllegalWrite,
    CT_UseAfterFree,
    CT_DoubleFree,
    CT_RaceCondition,
    CT_UndefinedBehavior,
    CT_UseOfStackAfterReturn,
};



//Need this to get a more illustrative call-stack for our example
#define DONT_INLINE __attribute__((noinline))

#define ITER_PER_THREAD 10000



struct Crash
{
    Crash();
    ~Crash();
    
    bool DONT_INLINE DoCrash(CRASH_TYPE type);
    
private:
    
    void DONT_INLINE crashWithIllegalRead();
    void DONT_INLINE readFromMemory(char* pMem);
    void DONT_INLINE crashWithIllegalWrite();
    void DONT_INLINE writeToMemory(char* pMem);
    void DONT_INLINE crashUseAfterFree();
    void DONT_INLINE useAfterFree(char* pMem);
    void DONT_INLINE crashDoubleFree();
    void DONT_INLINE doubleFree(char* pMem);
    int DONT_INLINE demoRaceCondition(int nNumberThreads);
    static void* DONT_INLINE threadRaceCondition(void *arg);

#if defined(__aarch64__)
    void DONT_INLINE demoUndefinedBehavior();
#endif

    void DONT_INLINE demoUseOfStackAfterReturn();
    const char* DONT_INLINE useOfStackAfterReturn();

};


#endif /* Crash_hpp */
