#!/usr/bin/env bash
# build.sh <envType>
# node-scripts 自动生成，请勿修改，并保证上传到 gitlab 上

BASE_DIR=${PWD}
echo "------------- build.sh start, pwd: ${PWD}, schema: ${SCHEMA_NAME}, envType: ${ENV_TYPE}, appname: ${APP_NAME}, baseDir: ${BASE_DIR} at $(date +%Y/%m/%d\ %H:%M:%S) ------------"

if [ -d ./node_modules ]; then
  echo "[node-scripts] remove exist node_modules directory!"
  safe_remove ./node_modules
fi

# make sure node version >= 4.0.0
nvm install 4

mkdir -p ${BASE_DIR}/node_modules/.bin
OS=`uname | tr '[:upper:]' '[:lower:]'` && echo "Current OS is $OS"
time curl -v -L http://enclose.alibaba-inc.com/packages/tnpm/latest/tnpm/${OS}-x64 | gunzip > ${BASE_DIR}/node_modules/.bin/tnpm
chmod +x ${BASE_DIR}/node_modules/.bin/tnpm

export PATH=${BASE_DIR}/node_modules/.bin:/usr/local/gcc-5.2.0/bin:$PATH

tnpm -v
time tnpm i --production --aone_app_pwd=${BASE_DIR} --aone_env_type=${ENV_TYPE} --aone_app_name=${APP_NAME} --aone_schema=${SCHEMA_NAME} || exit $?

# 执行 tnpm run build 来进行应用自定义的构建
echo "[node-scripts] start custom build: tnpm run build... at $(date +%Y/%m/%d\ %H:%M:%S) "
BUILD_ERROR=0
BUILD_OUTPUT=`tnpm run build 2>&1` || BUILD_ERROR=1
if [[ $BUILD_ERROR -eq 1 ]]
  then
  if [[ $BUILD_OUTPUT != *"missing script: build"* ]]
    then
    echo "$BUILD_OUTPUT"
    echo "[node-scripts] custom build error! please check your npm build script! at $(date +%Y/%m/%d\ %H:%M:%S) "
    exit 1
  else
    echo "[node-scripts] npm build script not exist, skip custom build. at $(date +%Y/%m/%d\ %H:%M:%S) "
  fi
else
  echo "$BUILD_OUTPUT"
  echo "[node-scripts] custom build success!"
fi

# 尝试执行 tnpm run autoproxy 自动生成 proxy 代码
echo "[node-scripts] try tnpm run autoproxy... at $(date +%Y/%m/%d\ %H:%M:%S) "
AUTOPROXY_ERROR=0
AUTOPROXY_OUTPUT=`tnpm run autoproxy 2>&1` || AUTOPROXY_ERROR=1
if [[ ${AUTOPROXY_ERROR} -eq 1 ]]
  then
  if [[ ${AUTOPROXY_OUTPUT} != *"missing script: autoproxy"* ]]
    then
    echo "${AUTOPROXY_OUTPUT}"
    echo "[node-scripts] autoproxy error! please check your npm autoproxy script! at $(date +%Y/%m/%d\ %H:%M:%S) "
    exit 1
  else
    echo "[node-scripts] npm autoproxy script not exist, skip. at $(date +%Y/%m/%d\ %H:%M:%S) "
  fi
else
  echo "${AUTOPROXY_OUTPUT}"
  echo "[node-scripts] autoproxy success!"
fi

echo "[node-scripts] build success! at $(date +%Y/%m/%d\ %H:%M:%S) "

echo "[node-scripts] reporting package.json to npm.alibaba-inc.com ... at $(date +%Y/%m/%d\ %H:%M:%S) "
tnpm i @ali/node-app-reporter@1
# $ node-app-reporter [baseDir] [appname] [buildId] [buildAuthor]
node-app-reporter ${BASE_DIR} ${APP_NAME} ${ENV_TYPE}
echo "[node-scripts] report success! at $(date +%Y/%m/%d\ %H:%M:%S) "
