import Foundation
import SwiftyJSON

class ChannelController: ClientAccesingControllerBase {
    
    public func updateChannelList(completion: @escaping (Bool, Error?) -> Void) {
        self.getClient().conversationsList() { response, error in
            for (_,subJson):(String, JSON) in response {
                let channel:Channel = Channel()
                if subJson["is_member"].bool == false {
                    continue
                }
                // IM channels.
                if subJson["name"].stringValue.isEmpty {
                    channel.setName(subJson["user"].stringValue)
                    channel.markAsDirectMessageChannel()
                }
                else {
                    var name = subJson["name_normalized"].stringValue;
                    name = name.replacingOccurrences(of: "mpdm-", with: "")
                    name = name.replacingOccurrences(of: "--", with: ", ")

                    channel.setName(name)
                }
                
                channel.setType(ChannelController.getChannelType(subJson))
                
                channel.setId(subJson["id"].stringValue)
                self.connection.addChannel(channel)
            }
            completion(true, error)
            
        }
    }
    
    public func getHistoryForChannel(channel: Channel, completion: @escaping(Bool, Error?) -> Void) {
        self.getClient().conversationsHistory(channelId: channel.getId()) { response, error in
            // Has to be reversed.
            for (_,subJson):(String, JSON) in response.reversed() {
                let message:Message = Message()
                message.setBody(ChannelController.getTextForMessage(subJson))
                message.setUserId(ChannelController.getUserForMessage(subJson))
                message.setTimeStamp(subJson["ts"].stringValue)
                channel.addMessage(message)
            }
            channel.markMessagesLoaded()
            completion(true, error)
        }
    }
    
    public static func getUserForMessage(_ JsonMessage: JSON) -> String {
        if (JsonMessage["user"].stringValue.isEmpty) {
            return "(BOT) " + JsonMessage["bot_id"].stringValue
        }
        return JsonMessage["user"].stringValue
    }
    
    public static func getTextForMessage(_ JsonMessage: JSON) -> String {
        if (!JsonMessage["text"].exists()) {
            return ""
        }
        var fullMessage:String = "";
        fullMessage += JsonMessage["text"].string!
        // Manage file. Duplicated in ConnectionWebSocketClient.swift
        if (!JsonMessage["files"].isEmpty){
            for file in JsonMessage["files"].arrayValue {
                let fileName = file["name"].string!;
                let privateUrl = file["url_private"].string!;
                
                // @todo: All left here is to put ! in front of the first [. However
                // we need permission for those urls. Havent found the correct documentation.
                // Perhaps we need to actually download the thumbnail locally.
                fullMessage += "[" + fileName + "](" + privateUrl + ")"
            }
        }
        
        if (!JsonMessage["attachments"].isEmpty){
            for attachment in JsonMessage["attachments"].arrayValue {
                fullMessage += attachment["fallback"].stringValue
            }
        }
        
        return fullMessage
    }
    
    // Determine the channel type.
    static func getChannelType(_ json: JSON) -> Int {
        if (json["is_im"].boolValue) {
            return Channel.directMessage
        }
        else if (json["is_group"].boolValue) {
            if (json["is_private"].boolValue) {
                return Channel.userGroup
            }
        }else if (json["is_channel"].boolValue) {
            if (json["is_private"].boolValue) {
                return Channel.lockedChannel
            }
        }
        return Channel.regularChannel
    }
    
}
