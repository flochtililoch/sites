umask 002

# Paths Config
mysql_default_file="/etc/mysql/debian.cnf"
root_dir="/var/www"
  sites_root_dir=$root_dir"/sites"
    bin_root_dir=$sites_root_dir"/bin"
    var_root_dir=$sites_root_dir"/var"
      shared_root_dir=$var_root_dir"/shared"
      mysql_output_dir=$var_root_dir"/sql"

# Go to a project root directory
function cdp () { 
  if [ ! -e $root_dir/$1 ]; then
    echo "Project $root_dir/$1 not found"
    return 1
  fi
  cd /var/www/$1
}

# Go to a project shared directory
function cds () { 
  if [ ! -e $shared_root_dir/$1 ]; then
    echo "Shared directory for project $1 not found"
    return 1
  fi
  cd $shared_root_dir/$1
}

# Create database
function db-create () {
  if [[ -z "$1" ]]; then
    echo "Usage: $FUNCNAME db_name"
    return 1
  fi
  dbuser="webdev@localhost"
  sudo mysql --defaults-file=$mysql_default_file -e "create database $1; grant all on $1.* to $dbuser; flush privileges;";
  echo "database $1 created, privileges granted to $dbuser"
}

# Drop database
function db-drop () {
  if [[ -z "$1" ]]; then
    echo "Usage: $FUNCNAME db_name"
    return 1
  fi
  sudo mysql --defaults-file=$mysql_default_file -e "drop database if exists $1;"; 
  echo "database $1 dropped"
}

# Dump database to file
function db-dump () {
  output_dir=$mysql_output_dir
  if [[ -z "$1" ]]; then
    echo "Usage: $FUNCNAME db_name [output_dir]"
    return 1
  fi
  if [ -n "$2" ]
  	then output_dir=$2
  fi
  dump="$output_dir/$1-`date +%FT%H-%M-%S`.sql" > $dump
  sudo mysqldump --defaults-file=$mysql_default_file $1 >> $dump
  echo "Database $1 dumped into $dump"
}

# Import SQL file to database
function db-import () {
  if [[ -z "$1" ]]; then
    echo "Usage: $FUNCNAME db_file [db_name]"
    return 1
  fi
  if [ -n "$2" ]
  	then db_name=$2
  	else
  		db_name=$(basename $db_file)
  		db_name=${db_name%%-*}
  fi
  cat $1 | sudo mysql --defaults-file=$mysql_default_file $db_name
  echo "$1 imported into $db_name"
}

# Clean up a project : fetch the last code, remove any modifications, drop db and reimport latest version
function cleanup () {
  if [[ -z "$1" ]]; then
    echo "Usage: $FUNCNAME project [db_file]"
    return 1
  fi
  project=$1
  db_name=${project//\-/\_}
  if [ -n "$2" ]
  	then db_file=$2
  	else 
  		db_file=$(ls -t1 ${var_root_dir}sql/${db_name}-* | head -n1)
  fi
  cdp ${project} && git clean -f -d && git pull && git reset --hard HEAD
  db-drop ${db_name}
  db-create ${db_name}
  db-import ${db_file}
}

# Sites Autocomplete
_list_sites() 
{
  local cur prev base
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  local projects=$(ls $root_dir)
  COMPREPLY=( $(compgen -W "${projects}" -- ${cur}) )
  return 0
}

# Databases autocomplete
_mysql_show()
{
	local cur opts
	cur="${COMP_WORDS[COMP_CWORD]}"
	opts=$(sudo mysql -B -ss -e "SHOW DATABASES;" )
	COMPREPLY=( $(compgen -W "${opts}" ${cur}) )
}

complete -F _mysql_show mysql
complete -F _mysql_show db-drop
complete -F _mysql_show db-dump
complete -F _list_sites cdp
complete -F _list_sites cds
complete -F _list_sites cleanup

alias dcc="drush cc all"
alias ll="ls -l"
alias la="ls -la"

PATH=$PATH:$bin_root_dir
export PATH