//
//  SWFMDBUtil.swift
//

import UIKit

let SQL_TEXT    = "TEXT"    // String
let SQL_INTEGER = "INTEGER" // Int
let SQL_REAL    = "REAL"    // Float Double
let SQL_BLOB    = "BLOB"    // Data
let SQL_DATE    = "DATE"    // Date
let SQL_ARRAY   = "ARRAY"   // 自定义类型
let SQL_MODEL   = "MODEL"   // 自定义类型

public class SWFMDBUtil: NSObject {
    // 获取文件名
    public static func getFileName(_ filePath: String) -> String {
        return URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
    }
    // 获取路径
    public static func dbPathForName(_ name: String) -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let documentPath = paths.first else {
            return ""
        }
        let dbPath = (documentPath as NSString).appendingPathComponent(name)
        return dbPath
    }
    // 存储类型转为字典
    public static func storageTypeToDictionary(_ model: Any) -> [String: Any] {
        var dic: [String: Any] = [:]
        if let cls = SWFMDBUtil.getModelClass(model) {
            dic = modelToDictionary(cls)
        }
        return dic
    }
    // 获取模型类
    public static func getModelClass(_ model: Any) -> AnyClass? {
        var cls: AnyClass?
        if let object = model as? NSObject {
            cls = type(of: object)
        } else {
            cls = model as? AnyClass
        }
        return cls
    }
    // 模型转字典
    public static func modelToDictionary(_ cls: AnyClass) -> [String: Any] {
        var dic: [String: Any] = [:]
        var outCount: UInt32 = 0
        guard let properties = class_copyPropertyList(cls, &outCount) else {
            return [:]
        }
        for i in 0..<Int(outCount) {
            // 属性名
            let nameCString = property_getName(properties[i])
            if let name = String(cString: nameCString, encoding: .utf8) {
                // 属性类型
                if let typeCString = property_getAttributes(properties[i]),
                   let type = String(cString: typeCString, encoding: .utf8) {
                    // 属性的类型换为数据库类型
                    let value = SWFMDBUtil.propertyTypeConvert(type)
                    if let value = value {
                        dic[name] = value
                    }
                }
            }
        }
        free(properties)
        return dic
    }
    // 属性类型转数据库类型
    public static func propertyTypeConvert(_ typeStr: String) -> String? {
        var resultStr: String?
        if typeStr.hasPrefix("T@\"NSString\"") {
            resultStr = SQL_TEXT
        } else if typeStr.hasPrefix("Tq") || typeStr.hasPrefix("TQ") {
            resultStr = SQL_INTEGER
        } else if typeStr.hasPrefix("Tf") || typeStr.hasPrefix("Td") {
            resultStr = SQL_REAL
        } else if typeStr.hasPrefix("T@\"NSData\"") {
            resultStr = SQL_BLOB
        } else if typeStr.hasPrefix("T@\"NSDate\"") {
            resultStr = SQL_DATE
        } else if typeStr.hasPrefix("T@\"NSArray\"") {
            resultStr = SQL_ARRAY
        } else if typeStr.hasPrefix("T@") {
            resultStr = SQL_MODEL
        }
        return resultStr
    }
    // 获取model属性的key和value
    public static func getModelPropertyKeyValue(_ model: Any, columnArray: [String]) -> [String: Any] {
        var dic = [String: Any]()
        let mirror = Mirror(reflecting: model)
        for case let (label?, value) in mirror.children {
            // 特殊判断，如果数据库表中不存这个字段 则跳过。
            if !columnArray.contains(label) {
                continue
            }
            dic[label] = value
        }
        return dic
    }
    
}
