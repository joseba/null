# Defined via `source`
function config --wraps='/usr/bin/git --gir-dir=$HOME/.cfg/ --work-tree=$HOME' --wraps='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME' --description 'alias config=/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $argv; 
end

function fish_title
    set -l command (echo $_)
    if test $command = "fish"
        echo "shell" (pwd)
    else
        echo $argv
    end
end

