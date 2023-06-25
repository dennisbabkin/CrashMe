//
//  main.cpp
//  CrashMe
//
//  Created by dennisbabkin.com on 6/25/23.
//
//  This project is a part of the blog post.
//  For more details, check:
//
//      https://dennisbabkin.com/blog/?i=AAA11600
//
//  This project demonstrates how to use Sanitizers in Xcode for macOS
//

#include <iostream>

#include "Crash.hpp"




int main(int argc, const char * argv[])
{
    Crash crash;

    std::cout << "CrashMe demo program for macOS." << std::endl;
    std::cout << "===============================" << std::endl;
    std::cout << std::endl;

    for(;;)
    {
        std::cout << "Select an option below:" << std::endl;
        
        std::cout << " 1. Crash with an illegal read." << std::endl;
        std::cout << " 2. Crash with an illegal write." << std::endl;
        std::cout << " 3. Crash with a use-after-free bug (requires Address Sanitizer)." << std::endl;
        std::cout << " 4. Crash with a double-free bug (requires Address Sanitizer)." << std::endl;
        std::cout << " 5. Demonstrate race condition bug (requires Thread Sanitizer)." << std::endl;
        std::cout << " 6. Demonstrate undefined behavior bug (requires Undefined Behavior Sanitizer & ARM-based CPU)." << std::endl;
        std::cout << " 7. Demonstrate a stack-use-after-return bug (requires Address Sanitizer/\"Detect use of stack after return\")." << std::endl;

        
        
        std::cout << std::endl;
        
        std::string strUsrChoice;
        std::cout << "Your choice: ";
        std::cin >> strUsrChoice;
     
        int nChoice = atoi(strUsrChoice.c_str());
        
        CRASH_TYPE type = CT_Unknown;
        
        if(nChoice == 1)
        {
            type = CT_IllegalRead;
        }
        else if(nChoice == 2)
        {
            type = CT_IllegalWrite;
        }
        else if(nChoice == 3)
        {
            type = CT_UseAfterFree;
        }
        else if(nChoice == 4)
        {
            type = CT_DoubleFree;
        }
        else if(nChoice == 5)
        {
            type = CT_RaceCondition;
        }
        else if(nChoice == 6)
        {
            type = CT_UndefinedBehavior;
        }
        else if(nChoice == 7)
        {
            type = CT_UseOfStackAfterReturn;
        }
        
        crash.DoCrash(type);
    }
    
    return 0;
}
