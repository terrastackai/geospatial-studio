# © Copyright IBM Corporation 2025
# SPDX-License-Identifier: Apache-2.0


# Check if geoserver is ready
sleep 10
echo "Loading \\c"

until kubectl logs --tail=2000 --follow=false -l app.kubernetes.io/name=gfm-geoserver -n ${OC_PROJECT} | grep "Catalina.start Server startup in" > /dev/null; do
    echo ".\\c"
    sleep 10
done
echo "\nUpdating settings"

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
