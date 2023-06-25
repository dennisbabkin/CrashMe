//
//  Crash.cpp
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


#include "Crash.hpp"




Crash::Crash()
{
}



Crash::~Crash()
{
}


bool Crash::DoCrash(CRASH_TYPE type)
{
    bool bRes = false;
    
    switch(type)
    {
        case CT_IllegalRead:
        {
            std::cout << "Attempting to crash this process with an illegal read ..." << std::endl;
            
            crashWithIllegalRead();
            
            bRes = true;
        }
        break;
            
        case CT_IllegalWrite:
        {
            std::cout << "Attempting to crash this process with an illegal write ..." << std::endl;
            
            crashWithIllegalWrite();
            
            bRes = true;
        }
        break;
            
        case CT_UseAfterFree:
        {
            std::cout << "Attempting to crash this process with a use-after-free bug ..." << std::endl;
            
            crashUseAfterFree();
            
            bRes = true;
        }
        break;
            
        case CT_DoubleFree:
        {
            std::cout << "Attempting to crash this process with a double-free bug ..." << std::endl;
            
            crashDoubleFree();
            
            bRes = true;
        }
        break;
            
        case CT_RaceCondition:
        {
            std::cout << "Demonstrating a race condition bug ..." << std::endl;
            
            int nNumberOfThreads = 5;
            int nReceivedResult = demoRaceCondition(nNumberOfThreads);
            
            int nRealResult = ITER_PER_THREAD * nNumberOfThreads;
            
            std::cout << "Received result: " << nReceivedResult <<
                      ", expected result: " << nRealResult << std::endl;
        }
        return true;
            
        case CT_UndefinedBehavior:
        {
#if defined(__aarch64__)
            std::cout << "Demonstrating an undefined behavior bug of unaligned read ..." << std::endl;
            
            demoUndefinedBehavior();
#else
            std::cout << "ERROR: Unsupported on this CPU..." << std::endl;
#endif
        }
        return true;
            
        case CT_UseOfStackAfterReturn:
        {
            std::cout << "Demonstrating a stack-use-after-return bug ..." << std::endl;
            
            demoUseOfStackAfterReturn();
        }
        return true;

            
        default:
        {
            std::cout << "ERROR: Bad selection, try again..." << std::endl << std::endl;
            break;
        }
    }
    
    if(bRes)
    {
        std::cout << "Oops. Did not crash! Try to enable Sanitizers in Xcode..." << std::endl << std::endl;
    }
    
    return bRes;
}


///Crash the process by reading from an illegal address
void Crash::crashWithIllegalRead()
{
    char* pMem = new (std::nothrow) char[128];
    
    readFromMemory(pMem);
    
    delete[] pMem;
}


void Crash::readFromMemory(char* pMem)
{
    assert(pMem);
    static char dummy = 0;
    
    for(size_t i = 0;; i++)
    {
        dummy += pMem[i];
    }
}




///Crash the process by writing into an illegal address
void Crash::crashWithIllegalWrite()
{
    char* pMem = new (std::nothrow) char[128];
    
    writeToMemory(pMem);
    
    delete[] pMem;
}


void Crash::writeToMemory(char* pMem)
{
    assert(pMem);
    
    for(size_t i = 0;; i++)
    {
        pMem[i] = (char)(int)i;
    }
}



///Crash the process by using use-after-free bug
void Crash::crashUseAfterFree()
{
    char* pMem = new (std::nothrow) char[128];
    
    useAfterFree(pMem);

}


void Crash::useAfterFree(char* pMem)
{
    delete[] pMem;
    
    *pMem = 0;              //Bug!!!
}



///Crash the process by using double-free bug
void Crash::crashDoubleFree()
{
    char* pMem = new (std::nothrow) char[128];
    
    doubleFree(pMem);

}


void Crash::doubleFree(char* pMem)
{
    delete[] pMem;
    delete[] pMem;          //Bug!!!

}





///Demonstrate a race-condition
int Crash::demoRaceCondition(int nNumberThreads)
{
    int nResult = 0;
    
    pthread_t* threads = new (std::nothrow) pthread_t[nNumberThreads];
    assert(threads);
    
    //Create threads for our tests
    for(int t = 0; t < nNumberThreads; t++)
    {
        int nErr = pthread_create(&threads[t], nullptr, threadRaceCondition, (void*)&nResult);
        assert(nErr == 0);
    }
    
    //Wait for threads to finish
    for(int t = 0; t < nNumberThreads; t++)
    {
        pthread_join(threads[t], nullptr);
    }
    
    //Free memory
    delete[] threads;

    return nResult;
}


void* Crash::threadRaceCondition(void *arg)
{
    int* pInt = (int*)arg;
    assert(pInt);
    
    for(int i = 0; i < ITER_PER_THREAD; i++)
    {
        (*pInt)++;
    }
    
    return nullptr;
}



#if defined(__aarch64__)

///Demonstrate undefined behavior bug (availabel on ARM64 CPU)
void Crash::demoUndefinedBehavior()
{
    char buff[32] = {};

    char* pSrc = buff;
    
    short v1 = *(int*)pSrc;
    pSrc += sizeof(v1);

    int v2 = *(int*)pSrc;       // Undefined behavior: unaligned read on an ARM CPU!
    pSrc += sizeof(v2);

    *(int*)buff = v1 + v2;
}

#endif


void Crash::demoUseOfStackAfterReturn()
{
    const char* pGreeting = useOfStackAfterReturn();

    printf("%s\n", pGreeting);      //bug!
}

const char* Crash::useOfStackAfterReturn()
{
    std::string str = "Hello world!";
    const char* pstr = str.c_str();
    
    return pstr;                    //bug!
}


