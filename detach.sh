#!/bin/bash
#
# @(#) detach.sh ver.1.0.0 2015.08.01
#
# Usage:
#   detach.sh param1
#     param1 - インスタンスID
#
# Description:
#   引数で指定されたインスタンスIDのインスタンスを、AutoScalingGroupから切り離し、
#   インスタンスを停止するスクリプト。
#   本スクリプトの実行には、下記ツールが必要。
#     - jq
#       jqインストールコマンド
#       - sudo curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && sudo chmod +x /usr/bin/jq
#     - aws cli
#   ※ aws cliには、クレデンシャル（or ロール）及びリージョン情報が登録済みであること。
#
###########################################################################

# 引数検証
if [ $# -ne 1 ]; then
  echo "Invalid Parameters." 1>&2
  exit 1
fi

# インスタンスの存在確認
INSTANCE_ID=$1
#export AWS_DEFAULT_REGION="ap-northeast-1"
echo "Instance Id: $INSTANCE_ID"
INSTANCE_NUM=`aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[0].Instances | length'`
if ! expr "$INSTANCE_NUM" : '[0-9]*' > /dev/null; then
  echo "  AWS Command Error." 1>&2
  exit 1
fi
if [ $INSTANCE_NUM -ne 1 ]; then
  echo "  $INSTANCE_ID is not found." 1>&2
  exit 1
fi

# インスタンスが紐づくAutoScalingGroup名を取得
echo "Getting AutoScaling group name..." 1>&2
AUTO_SCALING_GROUP_NAME=`aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[0].Instances[0].Tags[] | select(.Key=="aws:autoscaling:groupName").Value'`
if [ ${#AUTO_SCALING_GROUP_NAME} -eq 0 ]; then
  echo "  AUTO_SCALING_GROUP_NAME is not found in tags." 1>&2
  exit 1
fi
echo "  Name: $AUTO_SCALING_GROUP_NAME" 1>&2

# AutoScalingGroupからインスタンスを切り離す（デタッチ）
echo "Detach command executing..." 1>&2
ACTIVITY_ID=`aws autoscaling detach-instances --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTO_SCALING_GROUP_NAME --no-should-decrement-desired-capacity | jq -r '.Activities[0].ActivityId'`
if [ "$ACTIVITY_ID" = "" ]; then
  echo "  Detach command failed." 1>&2
  exit 1
fi

# デタッチ処理の終了を待つ
function waitActivitySuccessfull() {
  local ACTIVITY_ID=$1
  local LOOP_MAX=10
  for ((i=0; i < $LOOP_MAX; i++)); do
    echo "  Describing AutoScalingGroup activity status..." 1>&2
    local ACTIVITY_STATUS=`aws autoscaling describe-scaling-activities --activity-ids $ACTIVITY_ID | jq -r '.Activities[0].StatusCode'`
    echo "  Activity status: $ACTIVITY_STATUS" 1>&2
    if [ "$ACTIVITY_STATUS" = "Successful" ]; then
      return 0
    fi
    echo "  waiting 60 seconds..."
    sleep 60s
  done
  echo "  Retry max error. Detach activity failed." 1>&2
  exit 1
}
waitActivitySuccessfull $ACTIVITY_ID

# インスタンスを切り離し後、インスタンスを停止
echo "Stopping instance..." 1>&2
INSTANCE_STATUS=`aws ec2 stop-instances --instance-ids $INSTANCE_ID | jq -r '.StoppingInstances[0].CurrentState.Name'`
if [ "$INSTANCE_STATUS" != "stopping" ]; then
  echo "  Stop command failed." 1>&2
  exit 1
fi

# インスタンスの停止を待つ
function waitStoppedInstance() {
  local INSTANCE_ID=$1
  local LOOP_MAX=10
  for ((i=0; i < $LOOP_MAX; i++)); do
    local INSTANCE_STATUS=`aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[0].Instances[0].State.Name'`
    echo "  Instance status: $INSTANCE_STATUS" 1>&2
    if [ "$INSTANCE_STATUS" = "stopped" ]; then
      return 0
    fi
    echo "  waiting 60 seconds..."
    sleep 60s
  done
  echo "  Retry max error. Stop instance failed." 1>&2
  exit 1
}
waitStoppedInstance $INSTANCE_ID

# 終了
echo "All process finished." 1>&2
exit 0
