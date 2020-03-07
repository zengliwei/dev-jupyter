@echo off

cd /d %~dp0

::::
:: Collect project variables
::
set projectName=%dirName%
for /f "tokens=1,2 delims==" %%i in ( .env ) do (
  if %%i == COMPOSE_PROJECT_NAME (
    set projectName=%%j
  ) else if %%i == DOMAIN (
    set domain=%%j
  )
)

::::
:: Start project containers if created, otherwise create them
::
for /f "skip=1" %%c in ( 'docker ps -a --filter "name=%projectName%_web"' ) do (
  if not %%c == '' (
    call :START_PROJECT
    exit
  )
)
call :BUILD_PROJECT
exit


::::
:: Start containers
::
:START_PROJECT

  rename ..\..\config\router\%domain% %domain%.conf
  docker-compose start
  docker exec dev_router /usr/sbin/service nginx reload

goto :EOF


::::
:: Build project
::
:BUILD_PROJECT

  ::::
  :: Add host mapping
  ::
  set hostMappingSet=0
  for /f "tokens=1,2" %%i in ( %SystemRoot%\System32\drivers\etc\hosts ) do (
    if %%j == %domain% set hostMappingSet=1
  )
  if %hostMappingSet% == 0 (
    echo.>> %SystemRoot%\System32\drivers\etc\hosts
    echo.>> %SystemRoot%\System32\drivers\etc\hosts
    echo 127.0.0.1 %domain%>> %SystemRoot%\System32\drivers\etc\hosts
  )

  ::::
  :: Create proxy config file
  ::
  set proxySet=0
  for /f %%i in ( 'dir /b ..\..\config\router' ) do (
    if %%i == %domain% set proxySet=1
    if %%i == %domain%.conf set proxySet=1
  )
  if %proxySet% == 0 (
    for /f "tokens=1* delims=:" %%k in ( 'findstr /n .* .\config\router\proxy.conf' ) do (
      set "line=%%l"
      setLocal enableDelayedExpansion
      if "!line!" == "" (
        echo.>> proxy.conf.tmp
      ) else (
        set line=!line:project_name=%projectName%!
        set line=!line:project_domain=%domain%!
        echo !line!>> proxy.conf.tmp
      )
      endLocal
    )
    move proxy.conf.tmp ..\..\config\router\%domain%

    ::::
    :: Create SSL certificate
    ::
    for /f "tokens=1* delims=:" %%k in ( 'findstr /n .* .\config\router\ssl.conf' ) do (
      set "line=%%l"
      setLocal enableDelayedExpansion
      if "!line!" == "" (
        echo.>> ssl.conf.tmp
      ) else (
        set line=!line:project_domain=%domain%!
        echo !line!>> ssl.conf.tmp
      )
      endLocal
    )
    move ssl.conf.tmp ..\..\config\ssl\ext.cnf
    docker exec dev_router /usr/bin/openssl req -x509 -nodes -sha256 -newkey rsa:2048 -outform PEM -days 3650 -addext "basicConstraints=critical, CA:true" -subj "/C=CN/ST=State/L=Locality/O=Organization/CN=Dev - %domain%" -keyout ca.pvk -out /etc/ssl/certs/%domain%.browser.cer
    docker exec dev_router /usr/bin/openssl req -nodes -sha256 -newkey rsa:2048 -out server.req -keyout /etc/ssl/certs/%domain%.pvk -subj "/C=CN/ST=State/L=Locality/O=Organization/CN=%domain%"
    docker exec dev_router /usr/bin/openssl x509 -req -sha256 -days 3650 -set_serial 0x1111 -extfile /etc/ssl/certs/ext.cnf -in server.req -CAkey ca.pvk -CA /etc/ssl/certs/%domain%.browser.cer -out /etc/ssl/certs/%domain%.cer
    docker exec dev_router rm ca.pvk server.req /etc/ssl/certs/ext.cnf
  )

  ::::
  :: Create containers
  ::
  docker-compose up --no-recreate -d

  call :START_PROJECT

goto :EOF