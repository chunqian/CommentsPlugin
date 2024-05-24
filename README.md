# Comments Plugin

<img src="/Logo.png" style="width: 64px;" />

CommentsPlugin is a plugin specifically designed for Xcode. It meticulously replicates the convenient comment functionality of Sublime Text, providing an elegant and efficient code commenting experience.

## Build
```shell
cd CommentsPlugin
xcodebuild -resolvePackageDependencies -scmProvider system
```

## Installation

1. Run the application at least once, then close it.
2. Go to System Preferences > Extensions > Xcode Source Editor and enable this extension.
3. Reopen Xcode and you can find this extension from Xcode Menu > Editor.

## Setting Hot Key

1. After installation, open Xcode > Preferences > Key Bindings.
2. Search for "CommentsPlugin".
3. Assign it a new hot key, here "command + /" is recommended.

# License

Copyright 2023-2024 CHUNQIAN SHEN  

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.

You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.
