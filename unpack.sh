# 使用临时文件
#bash <(sed 's/eval/echo/' ${1}) > _tmp.sh
#while [[ "$(head _tmp.sh -c 7)" == "bash -c" ]]; do
#  bash <(sed 's/bash -c/echo/; s/bash "$@"//' _tmp.sh) > _tmp1.sh
#  mv _tmp1.sh _tmp.sh
#done
#mv _tmp.sh ${1}

# 使用内存变量
_tmp=$(bash <(sed 's/eval/echo/' ${1}))
while [[ "$(head -c 7 <<< ${_tmp})" == "bash -c" ]]; do
  _tmp=$(bash <(sed 's/bash -c/echo/; s/bash "$@"//' <<< ${_tmp}))
done
echo "${_tmp}" > ${1}
