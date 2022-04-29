#!/bin/bash

rc=0      # Return code
array=()  # サーバ＆ポート一覧保存用配列
config_file="/etc/nginx/stream.conf.d/servers.stream.conf" # 設定ファイルパス

# Configからサーバ＆ポート情報抽出
while read line || [ -n "${line}" ]; do
  # upstream行の設定から負荷分散対象グループ名を取得
  if [ $(echo ${line} | egrep "^upstream.*{" | wc -l) -ne 0 ]; then
    pool=$(echo ${line} | cut -d" " -f2)
  fi
  # server行の設定から、負荷分散対象サーバの情報を取得
  if [ $(echo ${line} | egrep "^server.*;" | wc -l) -ne 0 ]; then
    member=$(echo ${line} | cut -d" " -f2 | tr -d ";")
    array+=("${pool}:${member}")
  fi
done < <(cat ${config_file})

# ポートスキャン
for i in ${array[@]}
do
  # ポート番号取得
  server=$(echo $i | cut -d":" -f1)
  port=$(cat /etc/nginx/stream.conf.d/servers.stream.conf | egrep -B1 "proxy_pass.*${server}" | grep listen | awk '{print $3}' | tr -d ";")
  if [ "${port}" == "" ]; then
    port="tcp"
  fi

  # ポートスキャン
  if [ "${port}" == "tcp" ]; then
    # TCPの場合
    nc -nvz $(echo $i | cut -d":" -f2) $(echo $i | cut -d":" -f3) > /dev/null 2>&1
    if [ $(echo $?) -eq 0 ]; then
      result="up"
    else
      result="down"
      rc=$((${rc} + 1))
    fi
  else
    # UDPの場合
    nc -unvz $(echo $i | cut -d":" -f2) $(echo $i | cut -d":" -f3) > /dev/null 2>&1
    if [ $(echo $?) -eq 0 ]; then
      result="up"
    else
      result="down"
      rc=$((${rc} + 1))
    fi
  fi

  echo "$i:$port -> ${result}"
done

exit ${rc}
