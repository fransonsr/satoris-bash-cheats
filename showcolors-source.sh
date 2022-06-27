# see: https://stackoverflow.com/a/69648792

function showcolors256() {
    local row col blockrow blockcol red green blue
    local showcolor=_showcolor256_${1:-bg}
    local white="\033[1;37m"
    local reset="\033[0m"

    echo -e "Set foreground color: \\\\033[38;5;${white}NNN${reset}m"
    echo -e "Set background color: \\\\033[48;5;${white}NNN${reset}m"
    echo -e "Reset color & style:  \\\\033[0m"
    echo

    echo 16 standard color codes:
    for row in {0..1}; do
        for col in {0..7}; do
            $showcolor $(( row*8 + col )) $row
        done
        echo
    done
    echo

    echo 6·6·6 RGB color codes:
    for blockrow in {0..2}; do
        for red in {0..5}; do
            for blockcol in {0..1}; do
                green=$(( blockrow*2 + blockcol ))
                for blue in {0..5}; do
                    $showcolor $(( red*36 + green*6 + blue + 16 )) $green
                done
                echo -n "  "
            done
            echo
        done
        echo
    done

    echo 24 grayscale color codes:
    for row in {0..1}; do
        for col in {0..11}; do
            $showcolor $(( row*12 + col + 232 )) $row
        done
        echo
    done
    echo
}

function _showcolor256_fg() {
    local code=$( printf %03d $1 )
    echo -ne "\033[38;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}

function _showcolor256_bg() {
    if (( $2 % 2 == 0 )); then
        echo -ne "\033[1;37m"
    else
        echo -ne "\033[0;30m"
    fi
    local code=$( printf %03d $1 )
    echo -ne "\033[48;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}


function showcolors16() {
    _showcolor "\033[0;30m" "\033[1;30m" "\033[40m" "\033[100m"
    _showcolor "\033[0;31m" "\033[1;31m" "\033[41m" "\033[101m"
    _showcolor "\033[0;32m" "\033[1;32m" "\033[42m" "\033[102m"
    _showcolor "\033[0;33m" "\033[1;33m" "\033[43m" "\033[103m"
    _showcolor "\033[0;34m" "\033[1;34m" "\033[44m" "\033[104m"
    _showcolor "\033[0;35m" "\033[1;35m" "\033[45m" "\033[105m"
    _showcolor "\033[0;36m" "\033[1;36m" "\033[46m" "\033[106m"
    _showcolor "\033[0;37m" "\033[1;37m" "\033[47m" "\033[107m"
}

function _showcolor() {
    for code in $@; do
        echo -ne "$code"
        echo -nE "   $code"
        echo -ne "   \033[0m  "
    done
    echo
}
