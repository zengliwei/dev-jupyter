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
    for /f "tokens=1* delims=:" %%k in ( 'findstr /n .* .\config\proxy.conf' ) do (
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
  )

  ::::
  :: Create SSL certificate
  ::
  docker exec dev_router /usr/bin/openssl genrsa -out /etc/ssl/certs/%domain%.key 2048
  docker exec dev_router /usr/bin/openssl req -new -nodes -key /etc/ssl/certs/%domain%.key -out /etc/ssl/certs/%domain%.csr -subj /C=CN/ST=State/L=Locality/O=Organization/CN=%domain%
  docker exec dev_router /usr/bin/openssl x509 -req -days 3650 -signkey /etc/ssl/certs/%domain%.key -in /etc/ssl/certs/%domain%.csr -out /etc/ssl/certs/%domain%.crt
  docker exec dev_router rm /etc/ssl/certs/%domain%.csr

  ::::
  :: Create containers
  ::
  docker-compose up --no-recreate -d

  call :START_PROJECT

goto :EOF