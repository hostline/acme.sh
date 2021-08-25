#!/usr/bin/env sh

############################################################################
# Auteur       : DUVERNOY Matthieu
# Societe      : Hostline Hébergement VPS
# Contact      : contact@hostline.fr
# Creation     : 24/08/2021
# Modification : 25/08/2021
# Commentaire  : notre API s'appuie sur nos serveurs PowerDNS
# -------------------------------------------------------------------------#
# 24/08/2021 - MD :
#   - creation et adaptation du script depuis dns_pdns.sh
#   - test de bon fonctionnement : 
#       -> acme.sh --issue --staging --debug 2 -d test.hostline.fr -d *.test.hostline.fr --dns dns_hostline : test OK
# 25/08/2021 - MD :
#   - ajout des commentaires au script
#   - upload du script "dns_hostline.sh" sur GIT pour verification et validation [Y/N] : 
############################################################################



#
# Variables du fichier de configuration account.conf
# HOSTLINE_Url="https://api.hostline.fr"
# HOSTLINE_Token="xxx"
# HOSTLINE_Ttl=60
#

#
# declaration et initialisation des variables globales
DEFAULT_HOSTLINE_URL="https://api.hostline.fr"
DEFAULT_HOSTLINE_TTL=60
#



########  Public functions #####################
#
# ajout de la configuration dans le fichier account.conf et
# appel a la fonction d'ajout d'enregistrement TXT
dns_hostline_add() {

  #
  # declaration et initialisation des variables locales
  fulldomain=$1 # domaine sur lequel l'enregistrement sera effectif
  txtvalue=$2 # contenu de la valeur de l'enregistrement TXT
  #

  #
  # condition de verification de la variable HOSTLINE_Ttl personnalisee
  # si elle differente de la valeur actuelle on valorise avec la nouvelle valeur dans le fichier accound.conf
  if [ -z "$HOSTLINE_Url" ]; then
    HOSTLINE_Url="$DEFAULT_HOSTLINE_URL"
  fi

  #
  # condition de verification de la variable HOSTLINE_Token
  # si elle n'existe pas on retourne une erreur et on sort en CR1
  if [ -z "$HOSTLINE_Token" ]; then
    HOSTLINE_Token=""
    _err "You don't specify HOSTLINE_Token token"
    _err "Please create you HOSTLINE_Token and try again"
    return 1
  fi

  #
  # condition de verification de la variable HOSTLINE_Ttl
  # si elle existe on valorise avec la nouvelle valeur
  if [ -z "$HOSTLINE_Ttl" ]; then
    HOSTLINE_Ttl="$DEFAULT_HOSTLINE_TTL"
  fi

  #
  # ajout de la configuration dans le fichier account.conf
  _saveaccountconf HOSTLINE_Url "$HOSTLINE_Url"
  _saveaccountconf HOSTLINE_Token "$HOSTLINE_Token"
  _saveaccountconf HOSTLINE_Ttl "$HOSTLINE_Ttl"


  #
  # condition de verificiation du domaine racine
  # si le domaine n'est pas correcte on retourne une erreur et on sort en CR1
  _debug "Detect root zone"
  if ! _get_root "$fulldomain"; then
    _err "Invalid domain, please check domain and try again"
    return 1
  fi
  _debug _domain "$_domain"

  #
  # condition pour lancer l'enregistrement TXT dans le domain
  # si echec on retourne une erreur et on sort en CR1
  if ! set_record "$_domain" "$fulldomain" "$txtvalue"; then
    return 1
  fi

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



#
# fonction de suppression d'enregistrement TXT
dns_hostline_rm() {

  #
  # declaration et initialisation des variables locales
  fulldomain=$1 # domaine sur lequel l'enregistrement sera supprime
  txtvalue=$2 # contenu de la valeur de l'enregistrement TXT
  #
 
  #
  # condition de verification de la variable HOSTLINE_Ttl personnalisee
  # si elle differente de la valeur actuelle on valorise avec la nouvelle valeur dans le fichier accound.conf
  if [ -z "$HOSTLINE_Url" ]; then
    HOSTLINE_Url="$DEFAULT_HOSTLINE_URL"
  fi

  #
  # condition de verification de la variable HOSTLINE_Token
  # si elle n'existe pas on retourne une erreur et on sort en CR1
  if [ -z "$HOSTLINE_Token" ]; then
    HOSTLINE_Token=""
    _err "You don't specify HOSTLINE_Token token"
    _err "Please create you HOSTLINE_Token and try again"
    return 1
  fi

  #
  # condition de verification de la variable HOSTLINE_Ttl
  # si elle existe on valorise avec la nouvelle valeur
  if [ -z "$HOSTLINE_Ttl" ]; then
    HOSTLINE_Ttl="$DEFAULT_HOSTLINE_TTL"
  fi

  #
  # ajout de la configuration dans le fichier account.conf
  _saveaccountconf HOSTLINE_Url "$HOSTLINE_Url"
  _saveaccountconf HOSTLINE_Token "$HOSTLINE_Token"
  _saveaccountconf HOSTLINE_Ttl "$HOSTLINE_Ttl"
  

  #
  # condition de verificiation du domaine racine
  # si le domaine n'est pas correcte on retourne une erreur et on sort en CR1
  _debug "Detect root zone"
  if ! _get_root "$fulldomain"; then
    _err "Invalid domain, please check domain and try again"
    return 1
  fi
  _debug _domain "$_domain"

  #
  # condition pour lancer la suppression de l'enregistrement TXT
  # si echec on retourne une erreur et on sort en CR1
  if ! rm_record "$_domain" "$fulldomain" "$txtvalue"; then
    return 1
  fi

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



#
# fonction d'ajout d'enregistrement TXT
set_record() {

  _info "Adding record"
  
  #
  # declaration et initialisation des variables locales
  root=$1 # domaine racine
  full=$2 # domaine et sousdomaine
  new_challenge=$3 # nouveaux challenges

  #
  # appel aux fonctions
  # boucle de verification de la presence de challenge
  _record_string=""
  _build_record_string "$new_challenge"
  _list_existingchallenges
  for oldchallenge in $_existing_challenges; do
    _build_record_string "$oldchallenge"
  done

  #
  # appel a la fonction pour lancer l'enregistrement DNS
  # si echec on retourne une erreur et on sort en CR1
  if ! _hostline_rest "PATCH" "/api/v1/domain/dns/zones/$root" "{\"rrsets\": [{\"changetype\": \"REPLACE\", \"name\": \"$full.\", \"type\": \"TXT\", \"ttl\": $HOSTLINE_Ttl, \"records\": [$_record_string]}]}" "application/json"; then
    _err "Set txt record error."
    return 1
  fi

  #
  # condition desactivee !, on ne souhaite pas lancer de notify aux serveurs slaves
  #if ! notify_slaves "$root"; then
  #  return 1
  #fi

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



#
# fonction de suppression d'enregistrement TXT
rm_record() {

  _info "Remove record"

  #
  # declaration et initialisation des variables locales
  root=$1 # domaine racine
  full=$2 # domaine et sousdomaine
  txtvalue=$3 # non de l'enregistrement a supprimer

  #
  # appel aux fonctions
  # liste les challenges existants
  _list_existingchallenges

  #
  # appel aux fonctions
  # si les challenges existes bien on lance la suppression en faisant appel a l'API
  # si il n'y a pas de challenge on ne fait rien
  if _contains "$_existing_challenges" "$txtvalue"; then
    #
    # appel a la fonction pour supprimer les challenges dans le domaine
    # si echec on retourne une erreur et on sort en CR1
    if ! _hostline_rest "PATCH" "/api/v1/domain/dns/zones/$root" "{\"rrsets\": [{\"changetype\": \"DELETE\", \"name\": \"$full.\", \"type\": \"TXT\"}]}" "application/json"; then
      _err "Delete txt record error."
      return 1
    fi

    #
    # appel aux fonctions
    # boucle de verification de la presence de challenge
    _record_string=""
    if ! [ "$_existing_challenges" = "$txtvalue" ]; then
      for oldchallenge in $_existing_challenges; do
        #
        # si il existe encore des challenges on reconstruit l'enregistrement challenge pour suppression
        if ! [ "$oldchallenge" = "$txtvalue" ]; then
          _build_record_string "$oldchallenge"
        fi
      done

      #
      # appel a la fonction pour supprimer les challenges dans le domaine
      # si echec on retourne une erreur et on sort en CR1
      if ! _hostline_rest "PATCH" "/api/v1/domain/dns/zones/$root" "{\"rrsets\": [{\"changetype\": \"REPLACE\", \"name\": \"$full.\", \"type\": \"TXT\", \"ttl\": $HOSTLINE_Ttl, \"records\": [$_record_string]}]}" "application/json"; then
        _err "Set txt record error."
        return 1
      fi
    fi

  #
  # condition desactivee !, on ne souhaite pas lancer de notify aux serveurs slaves
  #if ! notify_slaves "$root"; then
  #  return 1
  #fi

  else

    # pas de challenges dans le domaine on ne fait rien
    _info "Record not found, nothing to remove"
  fi

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



#
# fonction de notification de modification aux serveurs slaves si il y en a
notify_slaves() {

  #
  # declaration et initialisation des variables locales
  root=$1

  #
  # appel a la fonction pour demander une mise a jour des enregistrements du domaine
  # si echec on retourne une erreur et on sort en CR1
  if ! _hostline_rest "PUT" "/api/v1/domain/dns/zones/$root/notify"; then
    _err "Notify slaves error."
    return 1
  fi

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



####################  Private functions below ##################################

#
# fonction pour retourner la list des zones disponible et
# verification de la disponibilite du domaine
_get_root() {

  #
  # declaration et initialisation des variables locales
  domain=$1
  i=1

  #
  # condition pour recuperer la liste des zones DNS et
  # normalisation du json
  if _hostline_rest "GET" "/api/v1/domain/dns/zones"; then
    _zones_response=$(echo "$response" | _normalizeJson)
  fi

  #
  # boucle pour extraire et verifier la conformite de domaine
  # si echec on retourne une erreur et on sort en CR1
  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)

    if _contains "$_zones_response" "\"name\":\"$h.\""; then
      _domain="$h."
      if [ -z "$h" ]; then
        _domain="=2E"
      fi

      #
      # si tout s'est bien passe on sort en CR0
      return 0
    fi

    if [ -z "$h" ]; then
      return 1
    fi
    i=$(_math $i + 1)
  done
  _debug "$domain not found"
  return 1
}



#
# fonction d'authentification et de traitement des requetes API
_hostline_rest() {

  #
  # declaration et initialisation des variables locales
  method=$1
  ep=$2
  data=$3
  ct=$4

  #
  # valorisation des variables du header pour l'appel API
  export _H1="Authorization: Basic $HOSTLINE_Token"
  export _H2="Accept: application/json"
  export _H3="Content-Type: application/json"

  #
  # condition si ce n'est pas la methode GET qui est appelee on fait du POST
  # sinon on appel la methode GET
  if [ ! "$method" = "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$HOSTLINE_Url$ep" "" "$method" "$ct")"
  else
    response="$(_get "$HOSTLINE_Url$ep")"
  fi

  #
  # si l'appel API fait un CR non 0 on retourne une erreur et on sort en CR1
  # sinon on affiche la reponse et on sort en CR0
  if [ "$?" != "0" ]; then
    _err "error $ep"
    return 1
  fi
  _debug2 response "$response"

  #
  # si tout s'est bien passe on sort en CR0
  return 0
}



#
# fonction de contruction des data envoyes a la requete API
_build_record_string() {

  #
  # valorisartion de la variable pour l'enregistrement DNS
  _record_string="${_record_string:+${_record_string}, }{\"content\": \"\\\"${1}\\\"\", \"disabled\": false}"
}



#
# fonction pour retourner les challenges de la zone DNS
_list_existingchallenges() {

  #
  # appel a l'API pour retourner les challenges
  _hostline_rest "GET" "/api/v1/domain/dns/zones/$root"

  #
  # valorisartion de la variable avec la reponse API
  _existing_challenges=$(echo "$response" | _normalizeJson | _egrep_o "\"name\":\"${fulldomain}[^]]*}" | _egrep_o 'content\":\"\\"[^\\]*' | sed -n 's/^content":"\\"//p')
}
