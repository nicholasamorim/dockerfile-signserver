# Use latest jboss/base-jdk:11 image as the base
# FROM jboss/base-jdk:11
FROM jboss/wildfly:14.0.1.Final

# Set the WILDFLY_VERSION env variable
# ENV WILDFLY_VERSION 14.0.1.Final
ENV SIGNSERVER_FILE signserver-ce-5.0.0.Beta1-bin.zip
ENV SIGNSERVER_FOLDER signserver-ce-5.0.0.Beta1
ENV SIGNSERVER_SHA512 ec0bf71a8dc47211908662e91394b4f585552fba68f45ad7402f4d6aa871a1bf5f210510033fe579b536e719b0dc24857f8c0f52861079bf4b331cafd9d3c039

ENV APPSRV_HOME $HOME/wildfly
USER root
COPY . /root

# RUN cd $HOME \
#     && curl -LO https://sourceforge.net/projects/signserver/files/signserver/5.0/$SIGNSERVER_FILE \
#     && sha512sum $SIGNSERVER_FILE | grep $SIGNSERVER_SHA512 \
#     && unzip $SIGNSERVER_FILE \
#     && rm $SIGNSERVER_FILE

RUN cd $HOME \
    && sha512sum $SIGNSERVER_FILE | grep $SIGNSERVER_SHA512 \
    && unzip -q $SIGNSERVER_FILE \
    && rm $SIGNSERVER_FILE


ENV MYSQL_JAR_LOCATION $HOME/wildfly/modules/system/layers/base/com/mysql/main/

RUN mkdir -p $MYSQL_JAR_LOCATION
RUN cd $HOME \
    && curl -LO https://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/8.0.15/mysql-connector-java-8.0.15.jar \
    && mv $HOME/mysql-connector-java-8.0.15.jar $MYSQL_JAR_LOCATION

RUN echo $' \
<?xml version="1.0" encoding="UTF-8"?> \
<resources>\
<resource-root path="mysql-connector-java-8.0.15.jar"/> \
</resources> \
<dependencies> \
<module name="javax.api"/> \
<module name="javax.transaction.api"/> \
</dependencies> \
</module>' > $MYSQL_JAR_LOCATION/module.xml

RUN echo $' \
batch \
/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql.jdbc,driver-xa-datasource-class-name=com.mysql.jdbc.jdbc2.optional.MysqlXADataSource) \
data-source add --name=UnifiedPushDS --driver-name=mysql --jndi-name=java:jboss/datasources/ExampleMySQLDS --connection-url=jdbc:mysql://localhost:3306/sample?useUnicode=true&amp;characterEncoding=UTF-8 --user-name=user --password=password --use-ccm=false --max-pool-size=25 --blocking-timeout-wait-millis=5000 --enabled=true\
run-batch' > commands.cli

RUN echo $' \
JBOSS_HOME=/opt/jboss/wildfly \
JBOSS_CLI=$JBOSS_HOME/bin/jboss-cli.sh \
JBOSS_MODE=${1:-"standalone"} \
JBOSS_CONFIG=${2:-"$JBOSS_MODE.xml"} \
function wait_for_server() { \
  until `$JBOSS_CLI -c "ls /deployment" &> /dev/null`; do \
    sleep 1 \
  done \
} \
echo "=> Starting WildFly server" \
$JBOSS_HOME/bin/$JBOSS_MODE.sh -c $JBOSS_CONFIG > /dev/null & \
echo "=> Waiting for the server to boot" \
wait_for_server \
echo "=> Executing the commands" \
$JBOSS_CLI -c --file=`dirname "$0"`/commands.cli \
echo "=> Shutting down WildFly" \
if [ "$JBOSS_MODE" = "standalone" ]; then \
  $JBOSS_CLI -c ":shutdown" \
else \
  $JBOSS_CLI -c "/host=*:shutdown" \
fi' > execute.sh $$ chmod +x execute.sh && ./execute.sh

ARG DB_HOST=mysql
ARG DB_NAME=mysql
ARG DB_USER=root
ARG DB_PASS=

ARG nodeid=node1
ENV SIGNSERVER_NODEID $nodeid

# # Add the WildFly distribution to /opt, and make wildfly the owner of the extracted tar content
# # Make sure the distribution is available from a well-known place
# RUN cd $HOME \
#     && curl -O "https://download.jboss.org/wildfly/14.0.1.Final/wildfly-14.0.1.Final.tar.gz" \
#     && sha1sum wildfly-14.0.1.Final.tar.gz | grep $WILDFLY_SHA1 \
#     && tar xf wildfly-14.0.1.Final.tar.gz \
#     && mv $HOME/wildfly-14.0.1.Final.tar.gz $JBOSS_HOME \
#     && rm wildfly-14.0.1.Final.tar.gz \
#     && chown -R jboss:0 ${JBOSS_HOME} \
#     && chmod -R g+rw ${JBOSS_HOME}

# # Ensure signals are forwarded to the JVM process correctly for graceful shutdown
# ENV LAUNCH_JBOSS_IN_BACKGROUND true

# USER jboss

# # Expose the ports we're interested in
# EXPOSE 8080

# # Set the default command to run on boot
# # This will boot WildFly in the standalone mode and bind to all interface
# CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
# RUN /opt/jboss/wildfly/customization/execute.sh
# CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
