@echo off

cd /d %~dp0

::::
:: Collect domain
::
for /f "tokens=1,2 delims==" %%i in ( .env ) do (
  if %%i == DOMAIN (
    set domain=%%j
  )
)
rename ..\..\config\router\%domain%.conf %domain%

docker-compose stop
docker exec dev_router /usr/sbin/service nginx reload
