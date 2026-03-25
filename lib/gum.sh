#!/bin/bash
# Gum helper library

gum_input() {
    local header=$1
    local placeholder=$2
    local default=$3
    gum input --placeholder "$placeholder" --value "$default" --header "$header"
}

gum_password() {
    local header=$1
    local placeholder=$2
    gum input --password --placeholder "$placeholder" --header "$header"
}

gum_choose() {
    local header=$1
    shift
    gum choose --header "$header" --cursor "● " --selected "○ " "$@"
}

gum_confirm() {
    local prompt=$1
    local accept=$2
    local reject=$3
    local default=${4:-false}
    
    if [[ "$default" == "true" ]]; then
        gum confirm --default=true --prompt.accept "$accept" --prompt.reject "$reject" "$prompt"
    else
        gum confirm --default=false --prompt.accept "$accept" --prompt.reject "$reject" "$prompt"
    fi
}

gum_spin() {
    local title=$1
    gum spin --spinner line -- "$title" --show-output
}
