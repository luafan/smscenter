return {
  ["sms_publickey"] = {
    ["publickey"] = "varchar(4096)",

    "INDEX `publickey` (`publickey`)",
  },
  ["sms_consumer"] = {
    ["publickeyid"] = "int(11) NOT NULL",
    ["pushtoken"] = "varchar(100)",
    ["status"] = "enum('active','uninstalled') NOT NULL DEFAULT 'active'",
    ["bundleidentifier"] = "varchar(100)",
    ["name"] = "varchar(255)",

    "INDEX `publickeyid` (`publickeyid`)",
  },
  ["sms_producer"] = {
    ["publickeyid"] = "int(11) NOT NULL",
    ["deviceid"] = "varchar(256)",
    "INDEX `publickeyid_deviceid` (`publickeyid`, `deviceid`)",
  },
  ["sms_body"] = {
    ["producerid"] = "int(11) NOT NULL",
    ["msg_id"] = "int(11) NOT NULL",
    ["msg_threadid"] = "int(11) NOT NULL",
    ["msg_type"] = "int(11) NOT NULL",
    ["msg_read"] = "int(11) NOT NULL",
    ["msg_status"] = "int(11) NOT NULL",
    ["msg_address"] = "varchar(128)",
    ["msg_person"] = "varchar(128)",
    ["msg_body"] = "varchar(1024)",
    ["msg_deskey"] = "varchar(1024)",
    ["msg_iv"] = "varchar(16)",
    ["msg_date"] = "bigint NOT NULL",

    "INDEX `producerid` (`producerid`)",
    "UNIQUE KEY `body` (`producerid`,`msg_id`)",
  }
}