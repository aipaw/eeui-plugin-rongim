//
//  eeuiRongcloudModule.m
//  WeexTestDemo
//
//  Created by apple on 2018/6/19.
//  Copyright © 2018年 TomQin. All rights reserved.
//

#import "eeuiRongcloudModule.h"
#import <RongIMLib/RongIMLib.h>
#import <CommonCrypto/CommonDigest.h>
#import "eeuiRongcloud.h"
#import <WeexPluginLoader/WeexPluginLoader.h>

@interface eeuiRongcloudModule () <RCIMClientReceiveMessageDelegate, RCConnectionStatusChangeDelegate>

@property (nonatomic, strong) NSString *roomID;
@property (nonatomic, copy) WXModuleKeepAliveCallback eventHeandlerCallback;

@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSString *userid;

@property (nonatomic, copy) WXModuleKeepAliveCallback statusCallback;

@property (nonatomic, assign) NSInteger errorStatusCount;

@end

@implementation eeuiRongcloudModule

WX_PlUGIN_EXPORT_MODULE(eeuiRongim, eeuiRongcloudModule)
WX_EXPORT_METHOD(@selector(login:callback:))
WX_EXPORT_METHOD(@selector(logout))
WX_EXPORT_METHOD(@selector(joinChatRoom:defMessageCount:callback:))
WX_EXPORT_METHOD(@selector(quitChatRoom:))
WX_EXPORT_METHOD(@selector(addEventHandler:))
WX_EXPORT_METHOD(@selector(removeEventHandler))
WX_EXPORT_METHOD(@selector(sendTextMessage:callback:))
WX_EXPORT_METHOD(@selector(sendTextMessageToUserid:text:callback:))

- (void)login:(id)params callback:(WXModuleKeepAliveCallback)callback
{
    if (![params isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSURL *URL = [NSURL URLWithString:@"https://api-cn.ronghub.com/user/getToken.json"];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";

    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"78" forHTTPHeaderField:@"Content-Length"];

    //header
    NSString *nonce = [NSString stringWithFormat:@"%d", rand()];
    long timestamp = (long)[[NSDate date] timeIntervalSince1970];
    NSString *unionString = [NSString stringWithFormat:@"%@%@%ld", [eeuiRongcloud getRongSec], nonce, timestamp];
    const char *cstr = [unionString cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:unionString.length];
    uint8_t digest[20];

    CC_SHA1(data.bytes, (unsigned int)data.length, digest);

    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    NSString *timestampStr = [NSString stringWithFormat:@"%ld", timestamp];

    [request setValue:[eeuiRongcloud getRongKey] forHTTPHeaderField:@"App-Key"];
    [request setValue:nonce forHTTPHeaderField:@"Nonce"];
    [request setValue:timestampStr forHTTPHeaderField:@"Timestamp"];
    [request setValue:output forHTTPHeaderField:@"Signature"];

    //params
    _userid = params[@"userid"] ? params[@"userid"] : @"";
    NSString *username = params[@"username"] ? params[@"username"] : @"";
    NSString *userimg = params[@"userimg"] ? params[@"userimg"] : @"";
    NSString *paramsStr = [NSString stringWithFormat:@"userId=%@&name=%@&portraitUri=%@", _userid, username, userimg];
    _statusCallback = callback;

    NSData *parametersData = [paramsStr dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:parametersData];
    __weak typeof(self) ws = self;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        if (error == nil && data != nil) {
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSLog(@"%@",result);
            ws.token = result[@"token"]?result[@"token"]:@"";

            if ([[NSString stringWithFormat:@"%@", result[@"code"]] intValue] != 200) {
                NSDictionary *res = @{@"status":@"error", @"userid":@"", @"token":@"", @"errorCode":result[@"code"], @"errorMsg":result[@"errorMessage"]};
                callback(res, NO);
                return;
            }

            [[RCIMClient sharedRCIMClient] setCurrentUserInfo:[[RCUserInfo alloc] initWithUserId:ws.userid name:username portrait:userimg]];

            [self performSelector:@selector(connectTimeOut) withObject:nil afterDelay:30];

            ws.errorStatusCount = 0;

            [[RCIMClient sharedRCIMClient] connectWithToken:ws.token success:^(NSString *userId) {
                NSDictionary *res = @{@"status":@"success", @"userid":ws.userid, @"token":ws.token, @"errorCode":@"", @"errorMsg":@""};
                ws.statusCallback(res, NO);
            } error:^(RCConnectErrorCode status) {
                if (status == RC_NET_CHANNEL_INVALID || status == RC_NET_UNAVAILABLE || status == RC_NAVI_REQUEST_FAIL || status == RC_NAVI_RESPONSE_ERROR || status == RC_NODE_NOT_FOUND || status == RC_SOCKET_NOT_CONNECTED || status ==  RC_SOCKET_DISCONNECTED || status == RC_PING_SEND_FAIL || status == RC_PONG_RECV_FAIL || status == RC_MSG_SEND_FAIL || status == RC_CONN_OVERFREQUENCY || status == RC_CONN_ACK_TIMEOUT || status == RC_CONN_PROTO_VERSION_ERROR || status == RC_CONN_SERVER_UNAVAILABLE || status == RC_CONN_REDIRECTED || status == RC_CONN_REFUSED || status == RC_CONNECTION_EXIST) {
                    [ws connectChangeStatus];
                } else {
                    NSDictionary *res = @{@"status":@"error", @"userid":ws.userid, @"token":ws.token, @"errorCode":@(status), @"errorMsg":@""};
                    callback(res, NO);
                }
            } tokenIncorrect:^{
                NSDictionary *res = @{@"status":@"error", @"userid":@"", @"token":@"", @"errorCode":@(0), @"errorMsg":@"token error"};
                callback(res, NO);
            }];

        } else {
            NSDictionary *res = @{@"status":@"error", @"userid":@"", @"token":@"", @"errorCode":@(error.code), @"errorMsg":error.domain};
            callback(res, NO);
        }
    }];
    [dataTask resume];
}

- (void)connectTimeOut
{
    if ([[RCIMClient sharedRCIMClient] getConnectionStatus] == ConnectionStatus_Connecting) {
        NSDictionary *res = @{@"status":@"error", @"userid":_userid, @"token":_token, @"errorCode":@"504", @"errorMsg":@"请求超时"};
        _statusCallback(res, NO);
    }
}

- (void)connectChangeStatus
{
    RCConnectionStatus status = [[RCIMClient sharedRCIMClient] getConnectionStatus];
    if (_errorStatusCount < 3) {
        if (status == ConnectionStatus_Connected) {
            NSDictionary *res = @{@"status":@"success", @"userid":_userid, @"token":_token, @"errorCode":@"", @"errorMsg":@""};
            _statusCallback(res, NO);
        } else {
            self.errorStatusCount++;

            dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, self.errorStatusCount*NSEC_PER_SEC);
            dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self connectChangeStatus];
            });
        }
    } else {
        NSDictionary *res = @{@"status":@"error", @"userid":_userid, @"token":_token, @"errorCode":@(status), @"errorMsg":[self msgError:status]};
        _statusCallback(res, NO);
    }
}

#pragma mark RCConnectionStatusChangeDelegate
- (void)onConnectionStatusChanged:(RCConnectionStatus)status
{
    if (status == ConnectionStatus_Connected) {
        NSDictionary *res = @{@"status":@"success", @"userid":_userid, @"token":_token, @"errorCode":@"", @"errorMsg":@""};
        _statusCallback(res, NO);
    } else if (status == ConnectionStatus_UNKNOWN || status == ConnectionStatus_NETWORK_UNAVAILABLE || status == ConnectionStatus_AIRPLANE_MODE || status == ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT || status == ConnectionStatus_LOGIN_ON_WEB || status == ConnectionStatus_SERVER_INVALID || status == ConnectionStatus_VALIDATE_INVALID  || status == ConnectionStatus_Unconnected || status == ConnectionStatus_SignUp || status == ConnectionStatus_TOKEN_INCORRECT || status == ConnectionStatus_DISCONN_EXCEPTION) {
        NSDictionary *res = @{@"status":@"error", @"userid":_userid, @"token":_token, @"errorCode":@(status), @"errorMsg":[self msgError:status]};
        _statusCallback(res, NO);
    }
}

- (NSString*)msgError:(RCConnectionStatus)status
{
    NSString *msg = @"";
    switch (status) {
        case ConnectionStatus_UNKNOWN:
            msg = @"未知状态";
            break;
        case ConnectionStatus_NETWORK_UNAVAILABLE:
            msg = @"当前设备网络不可用";
            break;
        case ConnectionStatus_AIRPLANE_MODE:
            msg = @"当前设备切换到飞行模式";
            break;
        case ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT:
            msg = @"当前用户在其他设备上登录，此设备被踢下线";
            break;
        case ConnectionStatus_LOGIN_ON_WEB:
            msg = @"当前用户在 Web 端登录";
            break;
        case ConnectionStatus_SERVER_INVALID:
            msg = @"服务器异常";
            break;
        case ConnectionStatus_VALIDATE_INVALID:
            msg = @"连接验证异常";
            break;
        case ConnectionStatus_Unconnected:
            msg = @"连接失败或未连接";
            break;
        case ConnectionStatus_SignUp:
            msg = @"已注销";
            break;
        case ConnectionStatus_TOKEN_INCORRECT:
            msg = @"Token无效";
            break;
        case ConnectionStatus_DISCONN_EXCEPTION:
            msg = @"与服务器的连接已断开,用户被封禁";
            break;

        default:
            break;
    }

    return msg;
}


- (void)logout
{
    [[RCIMClient sharedRCIMClient]
     logout];
}

- (void)joinChatRoom:(id)roomId defMessageCount:(NSInteger)defMessageCount callback:(WXModuleKeepAliveCallback)callback
{
    self.roomID = [NSString stringWithFormat:@"%@", roomId];
    [[RCIMClient sharedRCIMClient] joinChatRoom:self.roomID messageCount:(int)defMessageCount success:^{
        callback(@{@"status":@"success", @"errorCode":@"", @"errorMsg":@""}, NO);
    } error:^(RCErrorCode status) {
        callback(@{@"status":@"error", @"errorCode":@(status), @"errorMsg":@""}, NO);
    }];
}

- (void)quitChatRoom:(WXModuleKeepAliveCallback)callback
{
    [[RCIMClient sharedRCIMClient] quitChatRoom:self.roomID success:^{
        callback(@{@"status":@"success", @"errorCode":@"", @"errorMsg":@""}, NO);
    } error:^(RCErrorCode status) {
        callback(@{@"status":@"error", @"errorCode":@(status), @"errorMsg":@""}, NO);
    }];

}

- (void)addEventHandler:(WXModuleKeepAliveCallback)callback
{
    [[RCIMClient sharedRCIMClient] setReceiveMessageDelegate:self object:nil];
    self.eventHeandlerCallback = callback;
}

- (void)onReceived:(RCMessage *)message left:(int)nLeft object:(id)object
{
    if ([message.content isKindOfClass:[RCTextMessage class]]) {
        RCTextMessage *msg = (RCTextMessage*)message.content;
        NSString *userid = msg.senderUserInfo.userId ?msg.senderUserInfo.userId : @"";
        NSString *username = msg.senderUserInfo.name ? msg.senderUserInfo.name : @"";
        NSString *userimg = msg.senderUserInfo.portraitUri ? msg.senderUserInfo.portraitUri : @"";
        NSString *body = msg.content ? msg.content : @"";
        NSString *extra = msg.extra ? msg.extra : @"";

        if (self.eventHeandlerCallback) {
            NSDictionary *result = @{@"status":@"arrived", @"userid":userid, @"username":username, @"userimg":userimg, @"body":body, @"extra":extra};
            self.eventHeandlerCallback(result, YES);
        }
    }
}

- (void)removeEventHandler
{
    [[RCIMClient sharedRCIMClient] setReceiveMessageDelegate:nil object:nil];
}

- (void)sendTextMessage:(NSString*)text callback:(WXModuleKeepAliveCallback)callback
{
    RCTextMessage *msgContent = [RCTextMessage messageWithContent:text];
    msgContent.senderUserInfo = [[RCIMClient sharedRCIMClient] currentUserInfo];

    NSString *userid = msgContent.senderUserInfo.userId ? msgContent.senderUserInfo.userId : @"";
    NSString *username = msgContent.senderUserInfo.name ? msgContent.senderUserInfo.name : @"";
    NSString *userimg = msgContent.senderUserInfo.portraitUri ? msgContent.senderUserInfo.portraitUri : @"";
    NSString *body = msgContent.content ? msgContent.content : @"";
    NSString *extra = msgContent.extra ? msgContent.extra : @"";
    __weak typeof(eeuiRongcloudModule) *ws = self;
    [[RCIMClient sharedRCIMClient] sendMessage:ConversationType_CHATROOM
                                      targetId:self.roomID
                                       content:msgContent
                                   pushContent:nil
                                      pushData:nil
                                       success:^(long messageId) {
                                           callback(@{@"status":@"success"}, NO);

                                           if (ws.eventHeandlerCallback) {
                                               NSDictionary *result = @{@"status":@"send", @"userid":userid, @"username":username, @"userimg":userimg, @"body":body, @"extra":extra};
                                               ws.eventHeandlerCallback(result, YES);
                                           }                                       }
                                         error:^(RCErrorCode nErrorCode, long messageId) {

                                             callback(@{@"status":@"error", @"code":@(nErrorCode), @"error":[self ErrorCodeMsg:nErrorCode]}, NO);

                                             if (ws.eventHeandlerCallback) {
                                                 NSDictionary *result = @{@"status":@"send_error", @"userid":userid, @"username":username, @"userimg":userimg, @"body":body, @"extra":extra};
                                                 ws.eventHeandlerCallback(result, YES);
                                             }                                         }];
}

- (void)sendTextMessageToUserid:(NSString*)targetId text:(NSString*)text callback:(WXModuleKeepAliveCallback)callback
{
    RCTextMessage *msgContent = [RCTextMessage messageWithContent:text];
    msgContent.senderUserInfo = [[RCIMClient sharedRCIMClient] currentUserInfo];

    NSString *userid = msgContent.senderUserInfo.userId ? msgContent.senderUserInfo.userId : @"";
    NSString *username = msgContent.senderUserInfo.name ? msgContent.senderUserInfo.name : @"";
    NSString *userimg = msgContent.senderUserInfo.portraitUri ? msgContent.senderUserInfo.portraitUri : @"";
    NSString *body = msgContent.content ? msgContent.content : @"";
    NSString *extra = msgContent.extra ? msgContent.extra : @"";
    __weak typeof(eeuiRongcloudModule) *ws = self;
    [[RCIMClient sharedRCIMClient] sendMessage:ConversationType_PRIVATE
                                      targetId:targetId
                                       content:msgContent
                                   pushContent:nil
                                      pushData:nil
                                       success:^(long messageId) {
                                           callback(@{@"status":@"success"}, NO);

                                           if (ws.eventHeandlerCallback) {
                                               NSDictionary *result = @{@"status":@"send", @"userid":userid, @"username":username, @"userimg":userimg, @"body":body, @"extra":extra};
                                               ws.eventHeandlerCallback(result, YES);
                                           }                                       }
                                         error:^(RCErrorCode nErrorCode, long messageId) {

                                             callback(@{@"status":@"error", @"code":@(nErrorCode), @"error":[self ErrorCodeMsg:nErrorCode]}, NO);

                                             if (ws.eventHeandlerCallback) {
                                                 NSDictionary *result = @{@"status":@"send_error", @"userid":userid, @"username":username, @"userimg":userimg, @"body":body, @"extra":extra};
                                                 ws.eventHeandlerCallback(result, YES);
                                             }                                         }];
}

- (NSString *)ErrorCodeMsg:(RCErrorCode)code {
    if (code == ERRORCODE_UNKNOWN) {
        return @"未知错误（预留）";
    }
    else if (code == REJECTED_BY_BLACKLIST) {
        return @"已被对方加入黑名单";
    }
    else if (code == ERRORCODE_TIMEOUT) {
        return @"超时";
    }
    else if (code == SEND_MSG_FREQUENCY_OVERRUN) {
        return @"发送消息频率过高，1秒钟最多只允许发送5条消息";
    }
    else if (code == NOT_IN_DISCUSSION) {
        return @"不在该讨论组中";
    }
    else if (code == NOT_IN_GROUP) {
        return @"不在该群组中";
    }
    else if (code == FORBIDDEN_IN_GROUP) {
        return @"在群组中已被禁言";
    }
    else if (code == NOT_IN_CHATROOM) {
        return @"不在该聊天室中";
    }
    else if (code == FORBIDDEN_IN_CHATROOM) {
        return @"在该聊天室中已被禁言";
    }
    else if (code == KICKED_FROM_CHATROOM) {
        return @"已被踢出并禁止加入聊天室";
    }
    else if (code == RC_CHATROOM_NOT_EXIST) {
        return @"聊天室不存在";
    }
    else if (code == RC_CHATROOM_IS_FULL) {
        return @"聊天室成员超限";
    }
    else if (code == RC_PARAMETER_INVALID_CHATROOM) {
        return @"聊天室接口参数无效";
    }
    else if (code == RC_ROAMING_SERVICE_UNAVAILABLE_CHATROOM) {
        return @"聊天室云存储业务未开通";
    }
    else if (code == RC_CHANNEL_INVALID) {
        return @"当前连接不可用（连接已经被释放）";
    }
    else if (code == RC_NETWORK_UNAVAILABLE) {
        return @"当前连接不可用";
    }
    else if (code == RC_MSG_RESPONSE_TIMEOUT) {
        return @"消息响应超时";
    }
    else if (code == CLIENT_NOT_INIT) {
        return @"SDK没有初始化，在使用SDK任何功能之前，必须先Init。";
    }
    else if (code == DATABASE_ERROR) {
        return @"数据库错误，请检查您使用的Token和userId是否正确。";
    }
    else if (code == INVALID_PARAMETER) {
        return @"开发者接口调用时传入的参数错误，请检查接口调用时传入的参数类型和值。";
    }
    else if (code == MSG_ROAMING_SERVICE_UNAVAILABLE) {
        return @"历史消息云存储业务未开通";
    }
    else if (code == INVALID_PUBLIC_NUMBER) {
        return @"无效的公众号。(由会话类型和Id所标识的公众号会话是无效的)";
    }
    else if (code == RC_MSG_SIZE_OUT_OF_LIMIT) {
        return @"消息大小超限，消息体（序列化成json格式之后的内容）最大128k bytes。";
    }
    else if (code == RC_RECALLMESSAGE_PARAMETER_INVALID) {
        return @"撤回消息参数无效。";
    }
    else if (code == RC_PUSHSETTING_PARAMETER_INVALID) {
        return @"push设置参数无效。";
    }
    else if (code == RC_OPERATION_BLOCKED) {
        return @"操作被禁止。";
    }
    else if (code == RC_OPERATION_NOT_SUPPORT) {
        return @"操作不支持。";
    }
    else if (code == RC_MSG_BLOCKED_SENSITIVE_WORD) {
        return @"发送的消息中包含敏感词 （发送方发送失败，接收方不会收到消息）";
    }
    else if (code == RC_MSG_REPLACED_SENSITIVE_WORD) {
        return @"消息中敏感词已经被替换 （接收方可以收到被替换之后的消息）";
    }
    return @"";
}

@end
