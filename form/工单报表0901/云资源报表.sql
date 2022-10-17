SELECT
CASE
 JSON_UNQUOTE(json_extract(r.exts, "$.location" )) 
    WHEN 'shanghai' THEN '上海'
    WHEN 'wuhan' THEN '武汉'
    WHEN 'beijing' THEN '北京'
    WHEN 'guangzhou' THEN '广州'
    WHEN 'shenzhen' THEN '深圳'
    WHEN 'chengdu' THEN '成都'
    END '数据中心',
 rb.name '资源池',
  bg.name '业务组',
  rb.name '项目',
    r.external_name '虚拟机名称',
    u.name '所有者',
CASE
 r.STATUS 
 WHEN 'starting' THEN '正在启动' 
  WHEN 'started' THEN '已启动' 
    WHEN 'stopping' THEN '正在关机' 
  WHEN 'uninitialized' THEN '未初始化' 
 WHEN 'creating' THEN '正在创建' 
  WHEN 'configuring' THEN '正在配置' 
   WHEN 'configured' THEN '已配置' 
 WHEN 'stopped' THEN '已关机' 
    WHEN 'deleting' THEN '正在删除' 
  WHEN 'deleted' THEN '已删除' 
    WHEN 'purged' THEN '已清除' 
 WHEN 'lost' THEN '遗失' 
    END '状态',
   GROUP_CONCAT(DISTINCT rmna.value) '虚拟机IP地址',
 rm.cpu 'CPU(C)',
    rm.memory_in_mb / 1024 '内存(GB)',
		rm.total_storage_in_gb '存储',
    rm.os_description '操作系统版本',

 group_concat( concat_ws( ':', dlm.label_key, dlm.label_value, NULL ) ) '标签',
  rm.softwares '已装软件',
    d.provisioned_at '开始部署时间',
IF
  ( d.tear_down = 0, '永不过期', DATE_FORMAT( FROM_UNIXTIME( d.tear_down / 1000 ), '%Y-%m-%d %H:%i:%s' ) ) '租用到期时间',
IF
  (
     TIMESTAMPDIFF( DAY, d.provisioned_at, DATE_FORMAT( FROM_UNIXTIME( d.tear_down / 1000 ), '%Y-%m-%d %H:%i:%s' ) ) < 0,
     '永不过期',
     TIMESTAMPDIFF( DAY, now(), DATE_FORMAT( FROM_UNIXTIME( d.tear_down / 1000 ), '%Y-%m-%d %H:%i:%s' ) ) 
    ) '剩余租用天数',
 d.extend_times '已延期次数'
FROM
    resource r
    LEFT JOIN resource_machine rm ON r.id = rm.id AND r.class_type = 'openstack'
  LEFT JOIN resource_machine_network_address rmna ON r.id = rmna.resource_id
  LEFT JOIN deployment d ON r.deployment_id = d.id
  LEFT JOIN resource_bundle rb ON r.resource_bundle_id = rb.id
  LEFT JOIN business_group bg ON r.business_group_id = bg.id 
   LEFT JOIN user u ON r.owner_ids = u.id 
   LEFT JOIN project p ON r.group_id = p.id 
 LEFT JOIN dictionary_label_mapping dlm ON rm.id = dlm.entity_instance_id 
 WHERE r.deleted = 0
   AND r.class_type='openstack'
#   AND ifnull(r.business_group_id, '') LIKE '%${bgid}%' 
#   AND ifnull(r.owner_ids, '') LIKE '%${owner}%'
#   AND ifnull(r.group_id, '') LIKE '%${project_id}%' 
#  AND JSON_UNQUOTE(json_extract(r.exts,"$.location")) LIKE '%${location}%'
#  AND (r.name LIKE '%${filter}%' OR rmna.value LIKE '%${filter}%' OR r.external_name LIKE  '%${filter}%')
GROUP BY r.id