#!/usr/bin/env bash
is_mac() {
    [[ -d /Applications/Safari.app && -d /Users ]]
}

app_root() {
    loggedInUser=$(stat -f %Su /dev/console)
    echo "/Users/$loggedInUser/chef-vm-builder"
}

xcode_tools_installed() {
    xcode-select -p &> /dev/null
    [ $? -eq 0 ]
}

homebrew_installed() {
    which -s brew
    [ $? -eq 0 ]
}

elasticsearch_installed() {
    which -s elasticsearch
    [ $? -eq 0 ]
}

elasticsearch_is_running() {
    curl --stderr - localhost:9200 | grep -q cluster_name
    [ $? -eq 0 ]
}

install_homebrew() {
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    echo "Adding Homebrew services control..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew tap homebrew/services
}

install_elasticsearch() {
    echo "Adding the Elasticsearch repository..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew tap elastic/tap
    
    echo "Installing the Elasticsearch application..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew install elastic/tap/elasticsearch-full
}

start_elasticsearch() {
    echo "Starting Elasticsearch as a service..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew services start elastic/tap/elasticsearch-full
}

wait_for_elasticsearch_to_become_available() {
    host="localhost:9200"
    
    until $(curl --output /dev/null --silent --head --fail "$host"); do
        sleep 1
    done
    
    # First wait for ES to start...
    response=$(curl $host)
    
    until [ "$response" = "200" ]; do
        response=$(curl --write-out %{http_code} --silent --output /dev/null "$host")
        sleep 1
    done
    
    # next wait for ES status to turn to Green
    health="$(curl -fsSL "$host/_cat/health?h=status")"
    health="$(echo "$health" | sed -r 's/^[[:space:]]+|[[:space:]]+$//g')" # trim whitespace (otherwise we'll have "green ")
    
    until [ "$health" = 'green' ]; do
        health="$(curl -fsSL "$host/_cat/health?h=status")"
        health="$(echo "$health" | sed -r 's/^[[:space:]]+|[[:space:]]+$//g')" # trim whitespace (otherwise we'll have "green ")
        sleep 1
    done
    
    echo "Elasticsearch is available"
}

stop_elasticsearch() {
    echo "Stopping Elasticsearch..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew services stop elastic/tap/elasticsearch-full
}

wipe_elasticsearch() {
    echo "Wiping Elasticsearch..."
    curl -XDELETE localhost:9200/_all
}

uninstall_elasticsearch() {
    echo "Uninstalling Elasticsearch..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall elasticsearch-full
    
    echo "Removing the Elasticsearch Homebrew folder..."
    rm -rf /usr/local/var/homebrew/linked/elasticsearch-full
    
    echo "Removing configuration files..."
    rm -rf /usr/local/etc/elasticsearch/
    
    echo "Removing application data..."
    rm -rf /usr/local/var/lib/elasticsearch/
    
    echo "Removing logs..."
    rm -rf  /usr/local/var/log/elasticsearch/
    
    echo "Removing plugins..."
    rm -rf /usr/local/var/homebrew/linked/elasticsearch/plugins/
    rm -rf /usr/local/var/elasticsearch/
    
    echo "Removing the Elasticsearch repository..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew untap elastic/tap
}

no_root() {
    if [ -d $(app_root) ]; then
        false
    else
        true
    fi
}

create_root() {
    echo "Root doesn't exist, creating..."
    mkdir $(app_root)
}

root_is_empty() {
    find $(app_root) -name ".DS_Store" -delete
    if [ "$(ls -A $(app_root))" ]; then
        false
    else
        true
    fi
}

install_app() {
    echo "Installing builder..."
    git clone https://github.com/skukla/chef-vm-builder.git $(app_root)
}

drop_user_changes() {
    echo "Dropping all user changes..."
    git stash
    git stash drop
}

set_branch() {
    echo "Setting branch to $1..."
    cd $(app_root)
    git checkout $1
}

update_branch() {
    echo "Updating $1 branch..."
    git pull --rebase=true origin
}

update_app() {
    echo "Updating application..."
    sleep 1
    for branch in dev beta master; do
        set_branch $branch
        sleep 1
        drop_user_changes
        sleep 1
        update_branch $branch
        sleep 1
    done
}
