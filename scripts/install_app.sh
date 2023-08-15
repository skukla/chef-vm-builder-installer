#!/bin/bash
source functions.sh

if is_mac; then
    
    echo "PROGRESS:0"
    
    if [ ! xcode_tools_installed ]; then
        echo "ALERT:Warning|XCode Tools are not installed"
        echo "QUITAPP"
    fi
    
    if [ ! homebrew_installed ]; then
        echo "Homebrew is not installed";
        echo "ALERT:Warning|Homebrew is not installed"
        echo "QUITAPP"
    fi
    
    if no_root; then
        create_root
        sleep 1
    fi
    
    echo "PROGRESS:50"
    
    if root_is_empty; then
        install_app
        echo "PROGRESS:60"
        sleep 1
        set_branch master
        echo "PROGRESS:90"
        sleep 1
    else
        set_branch master
        echo "PROGRESS:60"
        sleep 1
        echo "PROGRESS:70"
        sleep 1
        update_app
        echo "PROGRESS:80"
        sleep 1
        echo "PROGRESS:90"
        sleep 1
    fi
    
    echo "PROGRESS:100"
    echo "ALERT:Success|Application has been installed or updated"
    echo "QUITAPP"
fi