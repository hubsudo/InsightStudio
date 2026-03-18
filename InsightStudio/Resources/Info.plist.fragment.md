在 Xcode 的 `Info.plist` 中加入以下配置，允许调试环境访问本地 HTTP 后端：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

如果你只想放开本地，也可以改成更细粒度白名单。
