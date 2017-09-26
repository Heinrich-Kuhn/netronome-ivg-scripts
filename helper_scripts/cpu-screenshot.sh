file_name=$1

echo q | htop | aha --black --line-fix > /root/IVG_folder/${file_name}.html
