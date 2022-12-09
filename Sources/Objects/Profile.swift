//
//  Profile.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
import Foundation

import Shared

// Profile struct implementation
//      creates a Profiles instance to be used by a Client to support the
//      processing of the profiles. Profile structs are added, removed and
//      updated by the incoming TCP messages. They are collected in the
//      ProfilesCollection.
@MainActor
public final class Profile: Identifiable, Equatable, ObservableObject {
  // Equality
  public nonisolated static func == (lhs: Profile, rhs: Profile) -> Bool {
    lhs.id == rhs.id
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: ProfileId) { self.id = id }
  
  @Dependency(\.apiModel) var apiModel

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: ProfileId
  public var initialized = false

  @Published public var current: ProfileName = ""
  @Published public var list = [ProfileName]()
  
  public enum Property: String {
    case list       = "list"
    case current  = "current"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
//  public static func status(_ properties: KeyValuesArray, _ inUse: Bool, _ statusMessage: String) {
//    // get the id
//    let id = properties[0].key
//    // is it in use?
//    if inUse {
//      // YES, add it if not already present
//      if ApiModel.shared.profiles[id: id] == nil { ApiModel.shared.profiles.append( Profile(id) ) }
//      // parse the properties
//      ApiModel.shared.profiles[id: id]!.parse( statusMessage )
//      
//    } else {
//      // NO, remove it
//      ApiModel.shared.profiles.remove(id: id)
//      log("Profile \(id): REMOVED", .debug, #function, #file, #line)
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse Profile key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ statusMessage: String?) {
    guard statusMessage != nil else { return }
    
    let properties = statusMessage!.keyValuesArray(delimiter: " ")
    let key = properties[1].key
        
    // check for unknown Key
    guard let token = Property(rawValue: key) else {
      // log it and ignore the Key
      log("Profile \(id): unknown property, \(key)", .warning, #function, #file, #line)
      return
    }
    // known keys
    switch token {
    case .list:
      let i = statusMessage!.index(statusMessage!.firstIndex(of: "=")!, offsetBy: 1)
      let suffix = String(statusMessage!.suffix(from: i))

      let values = suffix.valuesArray(delimiter: "^")
      list = values.last == "" ? Array(values.dropLast()) : values
//      print(list, i)
      
    case .current:    current = properties[1].value.isEmpty ? "none" : properties[1].value
      
    }
    // is it initialized?
    if initialized == false {
      // NO, it is now
      initialized = true
      log("Profile \(id): ADDED", .debug, #function, #file, #line)
    }
  }
  
  public static func setProperty(radio: Radio, _ id: ProfileId, property: Property, value: Any) {
    // FIXME: add commands
  }

//  public static func getProperty( _ id: ProfileId, property: Property) -> Any? {
//    switch property {
//    case .list:         return apiModel.profiles[id: id]!.list as Any
//    case .current:      return apiModel.profiles[id: id]!.current as Any
//    }
//  }

  /// Send a command to Set a Profile property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Amplifier
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: ProfileId, _ token: Property, _ value: Any) {
    // FIXME: add commands
  }
  
  /*
   "profile transmit save \"" + profile_name.Replace("*","") + "\""
   "profile transmit create \"" + profile_name.Replace("*", "") + "\""
   "profile transmit reset \"" + profile_name.Replace("*", "") + "\""
   "profile transmit delete \"" + profile_name.Replace("*", "") + "\""
   "profile mic delete \"" + profile_name.Replace("*","") + "\""
   "profile mic save \"" + profile_name.Replace("*", "") + "\""
   "profile mic reset \"" + profile_name.Replace("*", "") + "\""
   "profile mic create \"" + profile_name.Replace("*", "") + "\""
   "profile global save \"" + profile_name + "\""
   "profile global delete \"" + profile_name + "\""
   "profile mic load \"" + _profileMICSelection + "\""
   "profile tx load \"" + _profileTXSelection + "\""
   "profile display load \"" + _profileDisplaySelection + "\""
   "profile global load \"" + _profileGlobalSelection + "\""
   "profile global info"
   "profile tx info"
   "profile mic info"
   "profile display info"
   */
}
