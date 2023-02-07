#!/bin/sh


_exists() {
  cmd="$1"
  if [ -z "$cmd" ]; then
    _usage "Usage: _exists cmd"
    return 1
  fi

  if eval type type >/dev/null 2>&1; then
    eval type "$cmd" >/dev/null 2>&1
  elif command >/dev/null 2>&1; then
    command -v "$cmd" >/dev/null 2>&1
  else
    which "$cmd" >/dev/null 2>&1
  fi
  ret="$?"
  _debug3 "$cmd exists=$ret"
  return $ret
}




if [ -z "$1" ]; then 
    echo "Enter your CloudFlare email: "  
    read CF_EMAIL
else
    CF_EMAIL=$1
fi


if [ -z "$2" ]; then 
    echo "Enter CloudFlare global API key: "
    read CF_APIKEY
else
    CF_APIKEY=$2
fi


if [ -z "$3" ]; then 
    echo "Enter CloudFlare Domain ( whitout subdomain , Ex:google.com ): "  
    read CF_DOMAIN
else
    CF_DOMAIN=$3
fi


if [ -z "$4" ]; then 
    echo "Enter new subdomain ( without domain , Ex:iran ): "  
    read SUBDOMAIN_NAME
else
    SUBDOMAIN_NAME=$4
fi



if [ -z "$5" ]; then 
    echo "Enter server ip ( ipv4 ): "   
    read ORIGIN_IP
else
    ORIGIN_IP=$5
fi


echo "Email: $CF_EMAIL"
echo "ApiKey : $CF_APIKEY"
echo "Domain: $CF_DOMAIN"
echo "SubSomain: $SUBDOMAIN_NAME"
echo "OriginIP: $ORIGIN_IP"



# Find Zone ID
CF_ZONEID=$(curl -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_DOMAIN" -H "Content-Type:application/json" -H "X-Auth-Key: $CF_APIKEY" -H "X-Auth-Email: $CF_EMAIL" | sed -E "s/.+\"result\":\[\{\"id\":\"([a-f0-9]+)\".+/\1/g")

# json data for create a DNS record
data=$(echo "{\"id\":\"$CF_ZONEID\",\"type\":\"A\",\"proxied\":"true",\"name\":\"$SUBDOMAIN_NAME\",\"content\":\"$ORIGIN_IP\"}")

# create dns recored
update=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONEID/dns_records/" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "X-Auth-Key: $CF_APIKEY" \
    -H "Content-Type: application/json" \
    -d $data)
success=$(echo $update | sed -E "s/.+\"result\":\ ([a-z]+),\ \"success\":\ ([a-z]+).+/\2/g")

if [[ $success == "false" ]]; then
    message="API UPDATE FAILED. DUMPING RESULTS:\n$update"
    echo -e "$message"
    exit 1 
else
    message="IP changed to: $ORIGIN_IP"
    echo "$message"
fi
# echo "wait 10 seconds ... "
# sleep 10

if ! _exists "socat"; then
    _err "socat not installed , installing ..."
    apt install socat
fi

curl https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --register-account -m  "$CF_EMAIL"
~/.acme.sh/acme.sh --issue -d "$SUBDOMAIN_NAME.$CF_DOMAIN" --standalone
~/.acme.sh/acme.sh --installcert -d  "$SUBDOMAIN_NAME.$CF_DOMAIN" --key-file /root/auto_v2ray_certificate/private.key --fullchain-file /root/auto_v2ray_certificate/cert.crt

read -r -p "restart x-ui? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        echo "restarting ... "
        x-ui restart
        echo "restarted , Enjoy !"
        ;;
    *)
        echo "ok . bye"
        ;;
esac
