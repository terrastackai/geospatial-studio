# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


# Check if geoserver is ready
sleep 5
printf "Loading \n"

until curl --silent --show-error -u $GEOSERVER_USERNAME:$GEOSERVER_PASSWORD -f http://localhost:3000/geoserver/rest/workspaces > /dev/null; do
  echo "Endpoint not available yet. Sleeping for 5 seconds..."
  kubectl port-forward -n $OC_PROJECT svc/geofm-geoserver 3000:3000 >> studio-pf.log 2>&1 &
  kill -9 $(lsof -t -i:3000) > /dev/null 2>&1
  sleep 5
done

printf "\nUpdating settings\n"

# Create workspace
curl --silent --show-error -u $GEOSERVER_USERNAME:$GEOSERVER_PASSWORD -L -X POST http://localhost:3000/geoserver/rest/workspaces \
--header "Content-type: text/xml" \
--data '<workspace><name>geofm</name></workspace>'


# Update WMS Settings
curl --silent --show-error -u $GEOSERVER_USERNAME:$GEOSERVER_PASSWORD -L -X PUT http://localhost:3000/geoserver/rest/services/wms/settings \
--header "Content-type: application/json" \
--data '{"wms": {"maxBuffer": 25, "maxRequestMemory": 65536, "maxRenderingTime": 60, "maxRenderingErrors": 1000, "metadata": {"entry": [{"@key": "svgRenderer", "$": "Batik"},{"@key":"svgAntiAlias","$":"true"}]}}}'


# Allow services
curl --silent --show-error -u $GEOSERVER_USERNAME:$GEOSERVER_PASSWORD -L -X POST http://localhost:3000/geoserver/rest/security/acl/services \
--header "Content-type: application/json" \
--data '{"gwc.*":"*","wcs.*":"*","wfs.*":"*","wms.*":"*"}'

printf "\nCompleted geoserver configuration\n"
