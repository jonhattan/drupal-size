#!/bin/bash

if [ ${#@} -lt 1 ]; then
  echo "Generate report of the size/complexity of a Drupal project in html."
  echo ""
  echo "Usage: $0 <dbname> [flags]"
  echo ""
  echo "Flags:"
  echo -e "--db-connect\t\tCommand with arguments to connect the database. Defaults to 'mysql -A'"
  echo -e "--file\t\t\tFilename of the output report. Defaults to drupal-size-report.html"
  echo ""
  echo "Examples:"
  echo "  $0 db --db-connect='ddev mysql -A'"
  echo "  $0 dbname --db-connect='mysql -udbuser -pdbpass' --file=drupal-size-report.html"
  exit 1
fi

DB=$1
shift
DB_CONNECT='mysql -A'
OUTPUT='drupal-size-report.html'


options=$(getopt -o "" -l "db-connect:,file:" -- "$@")

eval set -- "$options"

while true; do
  case "$1" in
    --db-connect)
      shift
      DB_CONNECT=$1
      ;;
    --file)
      shift
      OUTPUT=$1
      ;;
    --)
      shift
      break;;
  esac
  shift
done


BUFFER=''
function title {
  LEVEL=$1
  TITLE=$2

  TAG="h${LEVEL}"
  TITLE="<${TAG}>${TITLE}</${TAG}>"
  BUFFER="${BUFFER} ${TITLE}"
}

function table {
  Q=$1

  TABLE=`echo "USE $DB; $Q" | $DB_CONNECT -H`
  BUFFER="${BUFFER} ${TABLE}"
}

function count {
  Q=$1

  COUNT=`echo "USE $DB; $Q" | $DB_CONNECT | wc -l`
  BUFFER="${BUFFER} <p>`expr ${COUNT} - 1` items</p>"
}

# Database size.
title 2 'Database size'
query="select count(table_name) as '# of tables', SUM(Round((data_length + index_length) / 1024 / 1024, 1)) as 'Size (in MB)' from information_schema.tables where table_schema='$DB';"
table "$query"

# Tables size.
title 2 '20 larger tables (by size)'
query="select table_name as 'Table', Round((data_length + index_length) / 1024 / 1024, 1) as MBsize, table_rows as 'Rows' from information_schema.tables where table_schema='$DB' order by MBsize DESC limit 20;"
table "$query"

# Enabled extensions.
title 2 'Modules and themes'
query='select type as "Type", count(name) as "Total enabled" from system where status=1 group by type;'
count "$query"
table "$query"

# Disabled modules.
title 2 'Disabled modules pending uninstall'
query='select name,schema_version from system where status=0 and schema_version != -1;'
count "$query"
table "$query"

# of variables.
title 2 '# of variables'
query='select name from variable;'
count "$query"

# Roles and users.
title 2 'Roles and users'
query='select r.rid as "Role ID", r.name as "Role name", count(*) as "# of users" from users u left join users_roles ur on ur.uid=u.uid left join role r on r.rid=ur.rid group by(r.rid);'
count "$query"
table "$query"

# Content-types.
title 2 'Content types'
query='select nt.name as Name, nt.type as "Machine name", count(*) as "# of nodes" from node n left join node_type nt on n.type = nt.type group by n.type'
count "$query"
table "$query"

# Bundles per entity type.
title 2 '# of bundles per entity type'
query='select entity_type as "Entity type", count(distinct(bundle)) as "Bundles" from field_config_instance fci group by entity_type order by entity_type;'
count "$query"
table "$query"

# Entity type bundles and # of fields.
title 2 'Entity type bundles and # of fields'
query='select entity_type as "Entity type", bundle as "Bundle", count(id) as "# of fields" from field_config_instance fci group by bundle, entity_type order by entity_type, bundle;'
count "$query"
table "$query"

# Menus and menu links.
title 2 'Menus and menu links'
query='select mc.title as "Name", mc.menu_name as "Machine name", count(mlid) as "# of menu items" from menu_custom mc left join menu_links ml ON ml.menu_name = mc.menu_name group by mc.menu_name;'
count "$query"
table "$query"

# Vocabularies and terms.
title 2 'Vocabularies and terms'
query='select v.vid, v.name as "Name", machine_name as "Machine name", count(*) as "# of terms" from taxonomy_term_data ttd left join taxonomy_vocabulary v on v.vid=ttd.vid group by vid;'
count "$query"
table "$query"

# Views and displays.
title 2 'Views and displays'
query='select vv.human_name as "View", vv.name as "Machine name", vd.display_title as "Display" from views_display vd left join views_view vv on vv.vid=vd.vid group by vv.vid;'
count "$query"
table "$query"

# Rules.
title 2 'Rules'
query='select label as "Rule", name as "Machine name" from rules_config;'
count "$query"
table "$query"

# Webforms and components.
title 2 'Webforms and components'
query='select w.nid as "Id",n.title as "Webform" ,count(cid) as "# of fields" from webform w left join webform_component wc on wc.nid=w.nid left join node n on n.nid=w.nid group by w.nid order by count(cid) DESC;'
count "$query"
table "$query"

echo $BUFFER > $OUTPUT
