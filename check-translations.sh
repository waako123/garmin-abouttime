for jungle in ./monkey-*.jungle; do
 lang=`echo $jungle | sed -e "s/^.*monkey-\(.*\)\.jungle.*$/\1/g"`
 uuid=`grep $lang translations.json | sed -e 's/^[^"]*"\([^"]*\)".*$/\1/g' | head -1`
 # echo "$lang: '$uuid'"
 if [ -z "$uuid" ]; then
  echo "No uuid for $lang"
 else
  html=`grep $uuid pages/index.html`
  if [ -z "$html" ]; then
   echo "No html for $lang ($uuid)"
  # else
   # echo $html
  fi
 fi
done

