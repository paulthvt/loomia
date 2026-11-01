# Changelog

## [v2026.11.2](https://github.com/paulthvt/loomia/compare/v2026.11.1...v2026.11.2) (2026-11-01)

### 🐛 Bug Fixes

- **contacts:** shorten "Add tag" instead of overflowing (#435) ([cf32716](https://github.com/paulthvt/loomia/commit/cf3271614bab5b2f2eb2d10969250b0c65da000d))

## [v2026.11.1](https://github.com/paulthvt/loomia/compare/v2026.10.8...v2026.11.1) (2026-11-01)

### ✨ Features

- **sharing:** tell me when an invite is accepted (#424) ([6f8c82b](https://github.com/paulthvt/loomia/commit/6f8c82bbddea71212aec6600d1a37fa047237bfc))
- **sharing:** share goals with the person mentoring you (#419) ([e03dac0](https://github.com/paulthvt/loomia/commit/e03dac04947baf7f4733f7e7c86398c091c121fe))

### 🐛 Bug Fixes

- **auth:** keep the Apple logo inside its button (#433) ([611599d](https://github.com/paulthvt/loomia/commit/611599dc463716da45757d43fac88140f0592e06))

### 📚 Documentation

- deploy Edge Functions from an up-to-date main (#426) ([a90e752](https://github.com/paulthvt/loomia/commit/a90e752ba0ab28f18b176ab548a89cdd7e69a8fc))
- **site:** spec and plan for the marketing site (#417) ([e642cf9](https://github.com/paulthvt/loomia/commit/e642cf9a5ed7917b93112afe04fe7b93515ad13d))

### 🔄 CI/CD

- **android:** upload and promote Play builds with fastlane (#410) ([0b6f37c](https://github.com/paulthvt/loomia/commit/0b6f37c807567ae44cab409e9ae895d3d04585ec))

### 🔧 Miscellaneous

- **l10n:** sync translations (#422) ([0a30f2f](https://github.com/paulthvt/loomia/commit/0a30f2f7fa22cb6b466a51de657ae45e2b7228be))
- **store:** App Store listing, privacy labels and screenshots (#429) ([364e793](https://github.com/paulthvt/loomia/commit/364e7933969a155fa4777697083073244bca6aea))
- **web:** drop loomia.thevenot.me from the Worker (#414) ([293ac1e](https://github.com/paulthvt/loomia/commit/293ac1e24e0aa48a370b316e65304a039a33ca4e))
- **l10n:** sync translations (#416) ([f1530d9](https://github.com/paulthvt/loomia/commit/f1530d980aa2aec7bc33ebe80a248bcc3972249d))
- **web:** move the web app to app.getloomia.app (#411) ([b884986](https://github.com/paulthvt/loomia/commit/b884986004fcfe13660baee085f89c8bad73714d))

## [v2026.10.8](https://github.com/paulthvt/loomia/compare/v2026.10.7...v2026.10.8) (2026-10-29)

### ✨ Features

- **auth:** sign in with Apple, and ask for a name when none comes (#408) ([c05380d](https://github.com/paulthvt/loomia/commit/c05380da00ba6b4eeb1060836df89bef7667b1e9))

### 🔄 CI/CD

- **ios:** pass TestFlight an absolute IPA path (#407) ([071cf68](https://github.com/paulthvt/loomia/commit/071cf68c2147438fa824ecdba30284b8800ba0e2))

## [v2026.10.7](https://github.com/paulthvt/loomia/compare/v2026.10.6...v2026.10.7) (2026-10-28)

### 🐛 Bug Fixes

- **layout:** start the desktop layout at 1200 (#404) ([362038d](https://github.com/paulthvt/loomia/commit/362038dd9055ae857bac3aa84c049c6ca9e11fb7))

### 🔄 CI/CD

- **ios:** sign releases with fastlane and ship them to TestFlight (#406) ([68f6ab9](https://github.com/paulthvt/loomia/commit/68f6ab94b18a6c3bff1a4a2a8244f7c6c1778f42))
- push migrations at merge, guard the released app (#395) ([4a9c20e](https://github.com/paulthvt/loomia/commit/4a9c20ecdd790a317cd8f8850f0a0e6d8ee1da51))

### 🔧 Miscellaneous

- **ios:** sign with the Loomia Apple team (#402) ([4693718](https://github.com/paulthvt/loomia/commit/46937180aec75c9b87efcae91444626974bf308f))

## [v2026.10.6](https://github.com/paulthvt/loomia/compare/v2026.10.5...v2026.10.6) (2026-10-28)

### ✨ Features

- **tasks:** a task page to view a task, edit from there (#392) ([35f1b75](https://github.com/paulthvt/loomia/commit/35f1b753c52db9cb1c2783928526ff0cd6f4dafa))
- **tasks:** a Tasks switch and a bell per timed task (#391) ([07b7957](https://github.com/paulthvt/loomia/commit/07b795705ed0d1440e72497152607b539a05977a))

### 🐛 Bug Fixes

- let Undo time out even with an accessibility service on (#387) ([461c014](https://github.com/paulthvt/loomia/commit/461c014073480c433a78f8b91096632da28ba3ae))

### 🔧 Miscellaneous

- **l10n:** sync translations (#393) ([b16606b](https://github.com/paulthvt/loomia/commit/b16606b9ec1f45eafddb9e539af8513e21a1dc23))

## [v2026.10.5](https://github.com/paulthvt/loomia/compare/v2026.10.4...v2026.10.5) (2026-10-27)

### ✨ Features

- **ui:** draw the tick and animate list changes (#385) ([3ad9fc1](https://github.com/paulthvt/loomia/commit/3ad9fc119fc40a99ad7550a8e6372d2e8b1f9723))
- **calendar:** show the people due on each day (#383) ([6f5a6b6](https://github.com/paulthvt/loomia/commit/6f5a6b6b168c16604e653b4e8ac4ae24723c377e))
- **tasks:** a time on a task, with a push at that time (#382) ([267d9f1](https://github.com/paulthvt/loomia/commit/267d9f16070c1e43395877dc81dae6e5ec88e62d))
- **tasks:** repeating tasks (#381) ([9a6b30d](https://github.com/paulthvt/loomia/commit/9a6b30d8755f8d79c2f3a769e4bd34b0162eabad))
- **tasks:** tasks on Today and in the Calendar (#380) ([8fe9668](https://github.com/paulthvt/loomia/commit/8fe96683c71a890c346ef87cd95d43868d89898d))
- **today:** undo a tick (#373) ([59b7492](https://github.com/paulthvt/loomia/commit/59b74922fc91ac19e329284eb6b95d252bc480ed))

### 🔧 Miscellaneous

- **l10n:** sync translations (#379) ([66c4ffd](https://github.com/paulthvt/loomia/commit/66c4ffddeb0e2a03aa56062bf3970441b9102f42))

## [v2026.10.4](https://github.com/paulthvt/loomia/compare/v2026.10.3...v2026.10.4) (2026-10-23)

### ✨ Features

- **calendar:** full-width month and hour-grid week on desktop (#367) ([75f80b3](https://github.com/paulthvt/loomia/commit/75f80b3059670322c740bab06aee96288272459d))

### 🐛 Bug Fixes

- **calendar:** hold the month still on mobile, scroll the list (#370) ([35aae9a](https://github.com/paulthvt/loomia/commit/35aae9afe4ffa0a84115cb6d2cd50e220d82803d))
- **calendar:** contain the month picker and let it scroll (#365) ([c79132d](https://github.com/paulthvt/loomia/commit/c79132dcf6549283c0b9ce2fc3a584d5f35e9595))

### 🔧 Miscellaneous

- **l10n:** sync translations (#371) ([6716a69](https://github.com/paulthvt/loomia/commit/6716a69b0359d479887bc53f36084f52b35137e7))

## [v2026.10.3](https://github.com/paulthvt/loomia/compare/v2026.10.2...v2026.10.3) (2026-10-20)

### ✨ Features

- **calendar:** edit a repeating event, this or following (#362) ([052a559](https://github.com/paulthvt/loomia/commit/052a5595a402bdab32e977c8c892ab66c4aa487c))
- **goals:** edit orders from the month's list (#361) ([58d5792](https://github.com/paulthvt/loomia/commit/58d5792d37333d155a1f81b9fe5ef9b55f62d3bf))
- **calendar:** week view, jump to a month, reliable swipes (#358) ([3dce422](https://github.com/paulthvt/loomia/commit/3dce4229acbc39f1e637d394cc18948148d20fde))
- **goals:** draft next month before it starts, close on the 1st (#355) ([d52892b](https://github.com/paulthvt/loomia/commit/d52892b78fd9d6bbeb72db08a103eba56603a6d4))

### 🔄 CI/CD

- **l10n:** tighten the Weblate pull request workflow (#350) ([d8abbb9](https://github.com/paulthvt/loomia/commit/d8abbb9c3a4c7a9123dd97f231b4b7d35e23f0f8))

### 🔧 Miscellaneous

- **l10n:** sync translations (#363) ([c7763f4](https://github.com/paulthvt/loomia/commit/c7763f4c9b13437c3e607a4c4b59200152a591d0))
- **l10n:** sync translations (#359) ([ed09e1f](https://github.com/paulthvt/loomia/commit/ed09e1f2cec633f483fd36b3641deadb8b2cf8ae))
- **l10n:** sync translations (#353) ([65bb10f](https://github.com/paulthvt/loomia/commit/65bb10f915a7d88916729dd919442246d5343a29))
- **deps:** update plugin org.jetbrains.kotlin.android to v2.4.21 (#211) ([95caf5b](https://github.com/paulthvt/loomia/commit/95caf5b4cbecf2de9d80a214da2448032444d9a3))
- **deps:** update dependency flutter to v3.47.7 (#229) ([da92d87](https://github.com/paulthvt/loomia/commit/da92d876ba076648a30bbeacef03dc321ea7107c))
- **l10n:** sync translations (#347) ([18f6b1e](https://github.com/paulthvt/loomia/commit/18f6b1e3a498f48734f3a9b2123936c868736e39))
- **l10n:** move translations to Weblate (#346) ([29e7c3d](https://github.com/paulthvt/loomia/commit/29e7c3d87ba1a2e09394c942b5457e32d08bdba2))

## [v2026.10.2](https://github.com/paulthvt/loomia/compare/v2026.10.1...v2026.10.2) (2026-10-16)

### ✨ Features

- **today:** catch up replaces worth a check-in (#343) ([064144e](https://github.com/paulthvt/loomia/commit/064144e760d4573ba5e7db462a94d03599143863))
- **contacts:** start-workflow switch when adding someone (#338) ([86c460d](https://github.com/paulthvt/loomia/commit/86c460d62a42381426f30a7b10d6a04909556bc4))
- **contacts:** tag contacts and filter by tag (#333) ([8292b28](https://github.com/paulthvt/loomia/commit/8292b280fcb01f2740f79d897400627b114229bc))

### 🔧 Miscellaneous

- **l10n:** sync translations (#339) ([3ae4645](https://github.com/paulthvt/loomia/commit/3ae4645c6a332cf098d548fc7b1c4b5af6c97752))
- **workflows:** rename Wellness check workflow to Wellness check invite (#341) ([da1e653](https://github.com/paulthvt/loomia/commit/da1e653fd679ff079cda1e28fa0ea37a0d2c559f))
- **l10n:** sync translations (#335) ([ade8e01](https://github.com/paulthvt/loomia/commit/ade8e012fc12995f00f90d82226a2ba09da2ac67))
- **calendar:** drop mark_event_done and the stage mapping columns (#336) ([0ac0516](https://github.com/paulthvt/loomia/commit/0ac0516432affa4050e334624ca252ab932ec0a0))

## [v2026.10.1](https://github.com/paulthvt/loomia/compare/v2026.10.0...v2026.10.1) (2026-10-15)

### ✨ Features

- **workflows:** new default workflows and account reset (#331) ([3f856aa](https://github.com/paulthvt/loomia/commit/3f856aa7581a7a2d0d4f6cf91614544459530c67))
- **calendar:** who was there records what changed (#330) ([bcf7856](https://github.com/paulthvt/loomia/commit/bcf7856ac0de9f053ac16e052399d7f2de94f961))
- **contacts:** LRP renewal reminder (#327) ([47649a2](https://github.com/paulthvt/loomia/commit/47649a27959f415b2ebe88b269540f13dc83836f))
- **workflows:** what's next when a workflow ends (#326) ([9fe7b3e](https://github.com/paulthvt/loomia/commit/9fe7b3eb01889882eaa6f5c73631761a0299cc9d))
- **workflows:** event steps (#325) ([fee1b06](https://github.com/paulthvt/loomia/commit/fee1b060df5d0612b15085bfe134566040030424))
- **calendar:** invitations on group events (#321) ([603f4f1](https://github.com/paulthvt/loomia/commit/603f4f154bb19e8fec717b97e455326439814c79))
- **goals:** push when it's time to close the month (#311) ([483d951](https://github.com/paulthvt/loomia/commit/483d951c3ff2c8b7b73434123ce4df79b584fc58))

### 🐛 Bug Fixes

- **app:** reset status bar icons after the launch splash (#309) ([50a4a9e](https://github.com/paulthvt/loomia/commit/50a4a9e0a2ff86cebf279506be7df0a2614cedc4))

### 📚 Documentation

- migrations stay compatible with the released app (#324) ([9422607](https://github.com/paulthvt/loomia/commit/9422607291d141207ad229cbc1911e1c3c15eabb))
- **workflows:** design for linked workflows and events (#320) ([da352db](https://github.com/paulthvt/loomia/commit/da352db4442b558d57014dcce20f17885854e635))

### 🔧 Miscellaneous

- **l10n:** sync translations (#322) ([80eb07b](https://github.com/paulthvt/loomia/commit/80eb07bf8004beb9a6b18763611e35329588b670))
- **l10n:** sync translations (#312) ([f5e4891](https://github.com/paulthvt/loomia/commit/f5e48911a90813d951e1a24c554da95caae52824))
- release with CalVer and yeet (#307) ([7f6e2b7](https://github.com/paulthvt/loomia/commit/7f6e2b7923767ed5ab0cba5cdc284922b17b1ff8))

## [0.11.0](https://github.com/paulthvt/loomia/compare/0.10.0...0.11.0) (2026-10-13)


### ✨ Features

* **calendar:** create repeating events ([#305](https://github.com/paulthvt/loomia/issues/305)) ([30a9c53](https://github.com/paulthvt/loomia/commit/30a9c53050ed29aefe9da6232a291acc9b637a3a))
* **calendar:** plain events ([#302](https://github.com/paulthvt/loomia/issues/302)) ([bb924ac](https://github.com/paulthvt/loomia/commit/bb924acc3976f7ba103eaf3b876cd60bfea812ae))
* **push:** choose the summary time on Today's card ([#289](https://github.com/paulthvt/loomia/issues/289)) ([3b88c40](https://github.com/paulthvt/loomia/commit/3b88c40784f0e959494d8708a28c1e98b9f13087))
* **today:** progress bar on the hero ([#293](https://github.com/paulthvt/loomia/issues/293)) ([c65dec5](https://github.com/paulthvt/loomia/commit/c65dec5b60bceabff76c7f9c86ec09fe4b814710))
* **workflows:** workflows that start over ([#304](https://github.com/paulthvt/loomia/issues/304)) ([df2d23c](https://github.com/paulthvt/loomia/commit/df2d23c9b9f20f9d8d2ab249de9d44c270c289ee))


### 📚 Documentation

* design repeating workflows and events, plain events ([#301](https://github.com/paulthvt/loomia/issues/301)) ([e008ea6](https://github.com/paulthvt/loomia/commit/e008ea6ef65d91fb997fdcaf87eb2c352661bfe7))


### 🔧 Miscellaneous

* **android:** drop ineffective forceDarkAllowed from the splash theme ([#295](https://github.com/paulthvt/loomia/issues/295)) ([8358ae8](https://github.com/paulthvt/loomia/commit/8358ae8fa732948538bf7425cb8cfbd68f6d64ff))
* **l10n:** sync translations ([#291](https://github.com/paulthvt/loomia/issues/291)) ([aa089be](https://github.com/paulthvt/loomia/commit/aa089bebd1668e67f096e6ca44cdc60371212d7c))
* **l10n:** sync translations ([#303](https://github.com/paulthvt/loomia/issues/303)) ([0bdfadd](https://github.com/paulthvt/loomia/commit/0bdfadd4a4971adeda0c83ec19013bb46eea1c63))

## [0.10.0](https://github.com/paulthvt/loomia/compare/0.9.0...0.10.0) (2026-10-12)


### ✨ Features

* **push:** ask for permission on a phone that hasn't allowed it ([#286](https://github.com/paulthvt/loomia/issues/286)) ([49982eb](https://github.com/paulthvt/loomia/commit/49982eb317eb9625fa68a15cd6b7e1834622b478))


### 🐛 Bug Fixes

* **push:** keep the push strings in release builds ([#284](https://github.com/paulthvt/loomia/issues/284)) ([2f1072e](https://github.com/paulthvt/loomia/commit/2f1072e9b853099ea8de895f123d226eeab76d11))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#287](https://github.com/paulthvt/loomia/issues/287)) ([db3d869](https://github.com/paulthvt/loomia/commit/db3d8695a52e653fe5ae2cb30a32fbe1a0bdb086))

## [0.9.0](https://github.com/paulthvt/loomia/compare/0.8.0...0.9.0) (2026-10-12)


### ✨ Features

* **push:** Firebase, device tokens and tap handling ([#272](https://github.com/paulthvt/loomia/issues/272)) ([f150431](https://github.com/paulthvt/loomia/commit/f1504314f28f0c1d06f84e50665b5fb738db173c))
* **push:** notification settings and the Today opt-in ([#277](https://github.com/paulthvt/loomia/issues/277)) ([4e41d9a](https://github.com/paulthvt/loomia/commit/4e41d9a7569fc21d3ac7bf62851fb5515ecb62a7))
* **push:** the daily summary sender ([#276](https://github.com/paulthvt/loomia/issues/276)) ([47ffca1](https://github.com/paulthvt/loomia/commit/47ffca13e29af6900592798824c0a29a0f09c481))


### 🐛 Bug Fixes

* **android:** keep the splash ochre under expanded dark theme ([#279](https://github.com/paulthvt/loomia/issues/279)) ([9b2910b](https://github.com/paulthvt/loomia/commit/9b2910b6eba2cef89766b160871752c1c394334f))
* **today:** wrap the summary offer buttons so French fits ([#281](https://github.com/paulthvt/loomia/issues/281)) ([23552a6](https://github.com/paulthvt/loomia/commit/23552a6c501d31d326aeb64132de2fd8264edae6))


### 📚 Documentation

* design push notifications ([#271](https://github.com/paulthvt/loomia/issues/271)) ([1533170](https://github.com/paulthvt/loomia/commit/1533170c4e41a8266de4ac37355d940753c290d3))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#274](https://github.com/paulthvt/loomia/issues/274)) ([de12a2e](https://github.com/paulthvt/loomia/commit/de12a2ef629c769e57b0f33227785be46ee1f150))

## [0.8.0](https://github.com/paulthvt/loomia/compare/0.7.0...0.8.0) (2026-10-10)


### ✨ Features

* show an offline state when the backend is unreachable ([#263](https://github.com/paulthvt/loomia/issues/263)) ([b465189](https://github.com/paulthvt/loomia/commit/b465189ba2033ca85d03173d57f7ae607eb0cbda))


### 🐛 Bug Fixes

* **auth:** drop offline token refresh failures from the auth stream ([#262](https://github.com/paulthvt/loomia/issues/262)) ([8e59c8f](https://github.com/paulthvt/loomia/commit/8e59c8fbfef7e692c4dcfaa5e537f3577e1dc502))
* **contacts:** open a known contact from import without a blank page ([#259](https://github.com/paulthvt/loomia/issues/259)) ([84d87a2](https://github.com/paulthvt/loomia/commit/84d87a2c23e9d85140eb161ab3af31cce6d8dfa2))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#264](https://github.com/paulthvt/loomia/issues/264)) ([482aa11](https://github.com/paulthvt/loomia/commit/482aa11887baf108a6b5efa52e1dcb75b30bc13a))
* log unexpected failures and send them to Sentry ([#266](https://github.com/paulthvt/loomia/issues/266)) ([709db11](https://github.com/paulthvt/loomia/commit/709db1106336adda57b94afbf29f2c7671a31a44))

## [0.7.0](https://github.com/paulthvt/loomia/compare/0.6.0...0.7.0) (2026-10-10)


### ✨ Features

* **contacts:** import in two steps, known numbers not ticked twice ([#250](https://github.com/paulthvt/loomia/issues/250)) ([39344f1](https://github.com/paulthvt/loomia/commit/39344f15c477d13811bceb8f9fbdcbbc9f235f70))
* **contacts:** LRP on the contact, counted in goals ([#256](https://github.com/paulthvt/loomia/issues/256)) ([37b2612](https://github.com/paulthvt/loomia/commit/37b2612faf6a35506572bd22074a660706c0076e))


### 🐛 Bug Fixes

* **ui:** centre the avatar vertically on action items ([#254](https://github.com/paulthvt/loomia/issues/254)) ([26dcec8](https://github.com/paulthvt/loomia/commit/26dcec8663f1c57aa4012dda3651fc3f6b163ca2))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#252](https://github.com/paulthvt/loomia/issues/252)) ([cccb465](https://github.com/paulthvt/loomia/commit/cccb4653df0b6e167d581b4e8b74a855f845e679))
* **l10n:** sync translations ([#257](https://github.com/paulthvt/loomia/issues/257)) ([52e95b5](https://github.com/paulthvt/loomia/commit/52e95b5390298c2737940f69a31b86f5fc0d9a91))

## [0.6.0](https://github.com/paulthvt/loomia/compare/0.5.0...0.6.0) (2026-10-09)


### ✨ Features

* **auth:** the Google picture as your photo ([#248](https://github.com/paulthvt/loomia/issues/248)) ([20b31e2](https://github.com/paulthvt/loomia/commit/20b31e2927edebdb9a4c25391d3a7274f740a43b))
* **contacts:** bring photos from the phone import ([#247](https://github.com/paulthvt/loomia/issues/247)) ([f07f3ad](https://github.com/paulthvt/loomia/commit/f07f3ade470fdbd5a9b5eda0083525f1e8725919))
* **contacts:** profile photos for contacts and yourself ([#244](https://github.com/paulthvt/loomia/issues/244)) ([06a7f90](https://github.com/paulthvt/loomia/commit/06a7f90ac864e26f4bb9be251a04db2638389dc7))


### 📚 Documentation

* profile photos design and upload plan ([#242](https://github.com/paulthvt/loomia/issues/242)) ([5a8f0f9](https://github.com/paulthvt/loomia/commit/5a8f0f9f0da341eb135d4c086492071b06cd341b))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#237](https://github.com/paulthvt/loomia/issues/237)) ([3fefd2f](https://github.com/paulthvt/loomia/commit/3fefd2f5964365753f419b5735017f5b3e30294d))
* **l10n:** sync translations ([#245](https://github.com/paulthvt/loomia/issues/245)) ([fb69e96](https://github.com/paulthvt/loomia/commit/fb69e96fee6da19e0306b98f77bb076c003f977b))

## [0.5.0](https://github.com/paulthvt/loomia/compare/0.4.0...0.5.0) (2026-10-09)


### ✨ Features

* **contacts:** sort Next step by due date, tell reminders from steps ([#231](https://github.com/paulthvt/loomia/issues/231)) ([d59850c](https://github.com/paulthvt/loomia/commit/d59850c39333a7db38ba0465da32585ec291c2b1))
* **today:** put the stage chip right after the name ([#234](https://github.com/paulthvt/loomia/issues/234)) ([a9cc7f3](https://github.com/paulthvt/loomia/commit/a9cc7f3c3dd9d18a5b6ef3f3349c55f72bfe1fa3))
* **today:** split Priority rows into the action and a quiet line ([#236](https://github.com/paulthvt/loomia/issues/236)) ([7904af7](https://github.com/paulthvt/loomia/commit/7904af7cea461f442a519cb1849fe49d7561e6cc))

## [0.4.0](https://github.com/paulthvt/loomia/compare/0.3.0...0.4.0) (2026-10-08)


### ✨ Features

* **calendar:** filter the Add people sheet by stage ([#216](https://github.com/paulthvt/loomia/issues/216)) ([b68f9c2](https://github.com/paulthvt/loomia/commit/b68f9c2657d4fa0c6be7af81d41eed42772c23ff))
* **contacts:** choose whether import starts the default workflow ([#226](https://github.com/paulthvt/loomia/issues/226)) ([a15451f](https://github.com/paulthvt/loomia/commit/a15451fab2a74dc4994e0a53e8c0fc11c5f5326e))
* **contacts:** Remind me in Log something ([#221](https://github.com/paulthvt/loomia/issues/221)) ([cdb296f](https://github.com/paulthvt/loomia/commit/cdb296fb14bcf91c21aa289b1b2993ceffdf9ce5))
* **reminders:** reminders on contacts and Today ([#220](https://github.com/paulthvt/loomia/issues/220)) ([776e312](https://github.com/paulthvt/loomia/commit/776e312d5bfa4d00efaba66a1913ca1fcaef4f41))
* **today:** show each person's stage on Priority cards ([#228](https://github.com/paulthvt/loomia/issues/228)) ([6007cc0](https://github.com/paulthvt/loomia/commit/6007cc000e16e2e5924dbdad8ce4cceb4ae97d7b))


### 🐛 Bug Fixes

* **contacts:** ticking a step counts as contact at once ([#223](https://github.com/paulthvt/loomia/issues/223)) ([53ed7c7](https://github.com/paulthvt/loomia/commit/53ed7c73d80dedbc301025a843c83ec0e69e792a))
* **shell:** back on a tab returns to Today instead of exiting ([#213](https://github.com/paulthvt/loomia/issues/213)) ([6c24846](https://github.com/paulthvt/loomia/commit/6c248465a6b8723a2d4f0ac754a7ffeaa0221833))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#224](https://github.com/paulthvt/loomia/issues/224)) ([dc88f65](https://github.com/paulthvt/loomia/commit/dc88f650a1c2e3fca37ecf42baf5c6e6f8fafd03))

## [0.3.0](https://github.com/paulthvt/loomia/compare/0.2.0...0.3.0) (2026-10-08)


### ✨ Features

* **calendar:** event workflows — a checklist per event, and what people start ([#201](https://github.com/paulthvt/loomia/issues/201)) ([8d1e592](https://github.com/paulthvt/loomia/commit/8d1e59212b9b4b96233a91ee1aea46c54769408a))
* **calendar:** events and the Calendar tab ([#197](https://github.com/paulthvt/loomia/issues/197)) ([a149507](https://github.com/paulthvt/loomia/commit/a149507de8b9371e26f1299635bf02adac120e74))
* **calendar:** invite people to an event and mark who was there ([#199](https://github.com/paulthvt/loomia/issues/199)) ([4d9b14d](https://github.com/paulthvt/loomia/commit/4d9b14d0522bbb98324487e37f701c3f41bcabdb))
* **calendar:** the month follows the finger when swiped ([#206](https://github.com/paulthvt/loomia/issues/206)) ([aab65d9](https://github.com/paulthvt/loomia/commit/aab65d99b75fccf2e1ac90998089a61ba51a286d))
* **today:** slide a checked card out, and its next step in ([#208](https://github.com/paulthvt/loomia/issues/208)) ([2184353](https://github.com/paulthvt/loomia/commit/2184353b5291079d0d4633381b60dcc554b857de))
* **today:** today's events, events to mark, and steps due ([#203](https://github.com/paulthvt/loomia/issues/203)) ([41e8531](https://github.com/paulthvt/loomia/commit/41e8531fade39ef88af5697c5437e29e028e0455))


### 🐛 Bug Fixes

* **calendar:** cap the month's width, centre the day hover ([#209](https://github.com/paulthvt/loomia/issues/209)) ([4d8d55f](https://github.com/paulthvt/loomia/commit/4d8d55f7882da6ec42257267b57a7d626014f8ff))
* **today:** hide an event's prep steps from its day on ([#210](https://github.com/paulthvt/loomia/issues/210)) ([62ce541](https://github.com/paulthvt/loomia/commit/62ce541a03786a5e69bce7e66e1b815fadb5b9ee))


### 🔧 Miscellaneous

* **deps:** update actions/upload-artifact digest to cf430e0 ([#198](https://github.com/paulthvt/loomia/issues/198)) ([9e85f1a](https://github.com/paulthvt/loomia/commit/9e85f1a0d6e3dec899a018fbd13c83be16bfd79a))
* **deps:** update dependency flutter to v3.47.6 ([#130](https://github.com/paulthvt/loomia/issues/130)) ([c23a14e](https://github.com/paulthvt/loomia/commit/c23a14e6b70cbebf6238bc860c62e7951f658e04))
* **deps:** update dependency supabase to v2.120.0 ([#188](https://github.com/paulthvt/loomia/issues/188)) ([70ae449](https://github.com/paulthvt/loomia/commit/70ae449b4e086f815674e0c74f686799aa8eb966))
* **deps:** update gradle to v9.8.1 ([#202](https://github.com/paulthvt/loomia/issues/202)) ([422daf4](https://github.com/paulthvt/loomia/commit/422daf4894685814b8f33c5e1e5d70b7e9439a4c))
* **l10n:** sync translations ([#200](https://github.com/paulthvt/loomia/issues/200)) ([a1727cc](https://github.com/paulthvt/loomia/commit/a1727cca1d4d44d517a26367dc6bcae17dfad9a3))
* share agent instructions in AGENTS.md and add Kiro steering ([#205](https://github.com/paulthvt/loomia/issues/205)) ([9c92607](https://github.com/paulthvt/loomia/commit/9c9260737ee944ac18ce9c8c563ef793fb63821b))

## [0.2.0](https://github.com/paulthvt/loomia/compare/v0.1.3...0.2.0) (2026-10-06)


### ✨ Features

* **contacts:** edit history entries ([#189](https://github.com/paulthvt/loomia/issues/189)) ([f4f6406](https://github.com/paulthvt/loomia/commit/f4f6406f29ff47aadcd2a71741d97358f7bd1294))
* **contacts:** pick several people to move, change workflow or delete ([#186](https://github.com/paulthvt/loomia/issues/186)) ([9b9a08b](https://github.com/paulthvt/loomia/commit/9b9a08b8e34ef3975162913238c4f051f1aa8adf))
* **contacts:** set when an imported stage began ([#184](https://github.com/paulthvt/loomia/issues/184)) ([6134580](https://github.com/paulthvt/loomia/commit/6134580fe852b8d72ec48b8c423528496803fbe0))
* **settings:** show the app version ([#194](https://github.com/paulthvt/loomia/issues/194)) ([d034ad5](https://github.com/paulthvt/loomia/commit/d034ad5aedc601d379533d232a259799f1885c1d))
* **ui:** make the resolve check an empty ring that fills on tap ([#192](https://github.com/paulthvt/loomia/issues/192)) ([50a0f32](https://github.com/paulthvt/loomia/commit/50a0f3237f7b81f28f92850020dd4cd5c5e3cd36))
* **web:** deploy to Cloudflare on release ([#181](https://github.com/paulthvt/loomia/issues/181)) ([377c7c7](https://github.com/paulthvt/loomia/commit/377c7c73f2104cee90f9c1bd008ddd874f59cbba))


### 🔧 Miscellaneous

* **l10n:** sync translations ([#185](https://github.com/paulthvt/loomia/issues/185)) ([9de275a](https://github.com/paulthvt/loomia/commit/9de275ae5a9c466f7e7e31a58d839339c7acbe22))
* **l10n:** sync translations ([#191](https://github.com/paulthvt/loomia/issues/191)) ([c8a6e28](https://github.com/paulthvt/loomia/commit/c8a6e281b0c5761d7b111fb63d583d12380fcd43))
* **l10n:** sync translations ([#195](https://github.com/paulthvt/loomia/issues/195)) ([4bb99e1](https://github.com/paulthvt/loomia/commit/4bb99e19249bd6bdbe021da9fb7436fa9fa3fbca))
* **release:** bump minor on feat commits ([#178](https://github.com/paulthvt/loomia/issues/178)) ([e8df940](https://github.com/paulthvt/loomia/commit/e8df940ebe13519b8a1cecd94b8250cae4deac94))
* **release:** drop the v prefix from release tags ([#183](https://github.com/paulthvt/loomia/issues/183)) ([63a3cc5](https://github.com/paulthvt/loomia/commit/63a3cc5cc728147892cd7a119fcef2f380f5e38f))

## [0.1.3](https://github.com/paulthvt/loomia/compare/v0.1.2...v0.1.3) (2026-10-05)


### ✨ Features

* **contacts:** a team member's rank and volume ([#160](https://github.com/paulthvt/loomia/issues/160)) ([cfebca0](https://github.com/paulthvt/loomia/commit/cfebca09e4144c4c0d6ece9786e05c00ca9c3fc2))
* **contacts:** amount on orders ([#158](https://github.com/paulthvt/loomia/issues/158)) ([66ff855](https://github.com/paulthvt/loomia/commit/66ff85542a2d0f8e55d9243af25650137be8344a))
* **goals:** close the month and plan the next ([#169](https://github.com/paulthvt/loomia/issues/169)) ([4e901a0](https://github.com/paulthvt/loomia/commit/4e901a03974af49a60479de6c7b51248f1d1ac03))
* **goals:** Goals tab ([#166](https://github.com/paulthvt/loomia/issues/166)) ([2b575c2](https://github.com/paulthvt/loomia/commit/2b575c273a3af6419e2fc51c0c4a7a175831bcbb))
* **goals:** log my own order and this month's orders ([#167](https://github.com/paulthvt/loomia/issues/167)) ([fd29495](https://github.com/paulthvt/loomia/commit/fd29495298bcc48549d752684af8e296f76d7eec))
* **goals:** month plans and progress in the database ([#164](https://github.com/paulthvt/loomia/issues/164)) ([ee19285](https://github.com/paulthvt/loomia/commit/ee1928513159e010a3ca8e0e5b0cf01874354639))
* **goals:** rank first, and picking it prefills OV ([#174](https://github.com/paulthvt/loomia/issues/174)) ([5e294f2](https://github.com/paulthvt/loomia/commit/5e294f2b7cd71c806e07ef7a7dbce173a33498c4))
* **layout:** two columns on desktop for Today, Goals, Team and the contact page ([#173](https://github.com/paulthvt/loomia/issues/173)) ([3ebfc83](https://github.com/paulthvt/loomia/commit/3ebfc8398904a7ecd30f6c7fba8f44401c931a2c))
* **onboarding:** ask which company the user works with ([#156](https://github.com/paulthvt/loomia/issues/156)) ([4f7eb16](https://github.com/paulthvt/loomia/commit/4f7eb160c8a7e12e373193d99b8af078f193af82))
* **today:** goal pace line and close-the-month card ([#170](https://github.com/paulthvt/loomia/issues/170)) ([810f79e](https://github.com/paulthvt/loomia/commit/810f79ef7d37108a88ef22b345caa992323df39b))
* **workflows:** mark a step as a loyalty setup ([#163](https://github.com/paulthvt/loomia/issues/163)) ([9cf0853](https://github.com/paulthvt/loomia/commit/9cf08539b9fe662e1c435f021f496c380b05088c))


### 🐛 Bug Fixes

* **l10n:** accept {text} replies from the fallback Gemini model ([#175](https://github.com/paulthvt/loomia/issues/175)) ([786eb8c](https://github.com/paulthvt/loomia/commit/786eb8cbee0547cf9ce098932a166fe16a50d689))
* **l10n:** review French copy ([#177](https://github.com/paulthvt/loomia/issues/177)) ([1b7af56](https://github.com/paulthvt/loomia/commit/1b7af56d9a05a7abfd382dbfa732e36da493dcc7))
* **shell:** keep the side rail usable on a landscape phone ([#132](https://github.com/paulthvt/loomia/issues/132)) ([7325a35](https://github.com/paulthvt/loomia/commit/7325a353762b67526e5860dd37647bf6d665692d))


### 🔧 Miscellaneous

* **deps:** lock file maintenance ([#172](https://github.com/paulthvt/loomia/issues/172)) ([0055599](https://github.com/paulthvt/loomia/commit/0055599757ac4269eae1e415eb573516be9ef9f8))
* **l10n:** sync translations ([#157](https://github.com/paulthvt/loomia/issues/157)) ([8634898](https://github.com/paulthvt/loomia/commit/8634898b02a8c56222b783aec464b26bafc18ed5))
* **l10n:** sync translations ([#168](https://github.com/paulthvt/loomia/issues/168)) ([08e6ebb](https://github.com/paulthvt/loomia/commit/08e6ebb339c5de4092fa301018c88aa5191ad7db))
* **l10n:** sync translations ([#176](https://github.com/paulthvt/loomia/issues/176)) ([9c28511](https://github.com/paulthvt/loomia/commit/9c285114be83d10561a22a023cdfde48211f733f))
* **supabase:** CI guard that every public table has RLS ([#135](https://github.com/paulthvt/loomia/issues/135)) ([9f7328d](https://github.com/paulthvt/loomia/commit/9f7328dc5c6c497fcf47c3e17f2a065d1cdbd9ec))
* **tooling:** set up graphify knowledge graph for Claude Code ([#162](https://github.com/paulthvt/loomia/issues/162)) ([43a8d12](https://github.com/paulthvt/loomia/commit/43a8d12f41240c39490e3e7811fa250f0b2367e0))

## [0.1.2](https://github.com/paulthvt/loomia/compare/v0.1.1...v0.1.2) (2026-10-01)


### ✨ Features

* **team:** Team tab with the roster ([#104](https://github.com/paulthvt/loomia/issues/104)) ([f6db969](https://github.com/paulthvt/loomia/commit/f6db969ff623c6574ff5dde8ae77231b5d8585a3))
* **team:** worth a check-in ([#122](https://github.com/paulthvt/loomia/issues/122)) ([2c88a25](https://github.com/paulthvt/loomia/commit/2c88a25579104c3c4152e9db53c3f772e039e766))


### 🐛 Bug Fixes

* **store:** screenshots of the whole app on phone, tablets and desktop ([#129](https://github.com/paulthvt/loomia/issues/129)) ([316138e](https://github.com/paulthvt/loomia/commit/316138e44bb1eaa296a91d35c445e545368504ca))


### 🔄 CI/CD

* **release:** user-friendly store release notes with Gemini ([#127](https://github.com/paulthvt/loomia/issues/127)) ([3538e27](https://github.com/paulthvt/loomia/commit/3538e273cb0291187ae55c3dc5418348a97550b1))


### 🔧 Miscellaneous

* **deps:** update dependency supabase to v2.119.0 ([#123](https://github.com/paulthvt/loomia/issues/123)) ([853aa44](https://github.com/paulthvt/loomia/commit/853aa44f0cfe787b6cccd507e92b4c9824ece2b8))
* **store:** Play screenshots rendered from the previews ([#126](https://github.com/paulthvt/loomia/issues/126)) ([aa82ccc](https://github.com/paulthvt/loomia/commit/aa82cccc0090940260016b07e8f99763721ed99a))

## [0.1.1](https://github.com/paulthvt/loomia/compare/v0.1.0...v0.1.1) (2026-09-30)


### ✨ Features

* **auth:** sign in, register, password reset and session guard ([#23](https://github.com/paulthvt/loomia/issues/23)) ([cd6afee](https://github.com/paulthvt/loomia/commit/cd6afeeac9b7280142b3a11543122a5c79a4a219))
* **brand:** animated launch splash ([#96](https://github.com/paulthvt/loomia/issues/96)) ([ee95437](https://github.com/paulthvt/loomia/commit/ee954375b9e36a4c2a581a6d1a1087e82a2329cd))
* **brand:** Loomia wordmark and app icons ([#94](https://github.com/paulthvt/loomia/issues/94)) ([89f7f80](https://github.com/paulthvt/loomia/commit/89f7f805544d9f7de5efb62a068e9e68690d76f5))
* **contacts:** a team member's own profile, in their words ([#76](https://github.com/paulthvt/loomia/issues/76)) ([f1cf62a](https://github.com/paulthvt/loomia/commit/f1cf62aba3d8c68d40a4ec0a3ebd947f0feeaaa5))
* **contacts:** history, Log something and stage changes ([#68](https://github.com/paulthvt/loomia/issues/68)) ([75bab0a](https://github.com/paulthvt/loomia/commit/75bab0a06e00b384200b4da5558638fc9e16504e))
* **contacts:** import contacts from the phone, offered once at first run ([#78](https://github.com/paulthvt/loomia/issues/78)) ([68aae7a](https://github.com/paulthvt/loomia/commit/68aae7a1bb26a20421417660c18152932daa53af))
* **contacts:** see a person's whole workflow as a timeline ([#80](https://github.com/paulthvt/loomia/issues/80)) ([76f00bc](https://github.com/paulthvt/loomia/commit/76f00bc52100bdcebc0567048a22a6c3f55a2dbb))
* database conventions and the person table ([#63](https://github.com/paulthvt/loomia/issues/63)) ([5125099](https://github.com/paulthvt/loomia/commit/5125099df0f0d7be6691b01f8e0e9f88b7daba62))
* **l10n:** set up localization with English and French ([#26](https://github.com/paulthvt/loomia/issues/26)) ([332dbd7](https://github.com/paulthvt/loomia/commit/332dbd7c4848630fcca0e73bee9465a6bb62ad32))
* **motion:** apply the motion system across the app ([#25](https://github.com/paulthvt/loomia/issues/25)) ([c653ec3](https://github.com/paulthvt/loomia/commit/c653ec3d10dfc893d4022190666979fb712357dd))
* people with a stage — Contacts, a person, Add and Edit ([#64](https://github.com/paulthvt/loomia/issues/64)) ([7a765bb](https://github.com/paulthvt/loomia/commit/7a765bbe928b196257a30da84309522e26ae928d))
* **settings:** choose light or dark appearance ([#38](https://github.com/paulthvt/loomia/issues/38)) ([7410501](https://github.com/paulthvt/loomia/commit/741050144af0f72096da2c0e8578d4a88077b09f))
* **settings:** settings list with account and language sections ([#36](https://github.com/paulthvt/loomia/issues/36)) ([a3975f8](https://github.com/paulthvt/loomia/commit/a3975f82ac6e054c4b47b29fc813c99c2ad2c5f9))
* **shell:** app shell with sidebar and a settings screen ([#33](https://github.com/paulthvt/loomia/issues/33)) ([876b620](https://github.com/paulthvt/loomia/commit/876b62049a7b4e119e3e911813f9cc1bb1e1c5c4)), closes [#29](https://github.com/paulthvt/loomia/issues/29)
* **theme:** implement the design system tokens ([#15](https://github.com/paulthvt/loomia/issues/15)) ([5aed6eb](https://github.com/paulthvt/loomia/commit/5aed6eb63f817b5e02e1dd8234bd2e1ac4d4a2c4))
* **theme:** Loomia palette ([#87](https://github.com/paulthvt/loomia/issues/87)) ([b825dd0](https://github.com/paulthvt/loomia/commit/b825dd04013ed9029bc66c3743f624c5f8dc30d0))
* **today:** build the Today screen and the components it needs ([#17](https://github.com/paulthvt/loomia/issues/17)) ([7edfe49](https://github.com/paulthvt/loomia/commit/7edfe496c7fd214f094b311d34283b55caf4da79))
* **today:** suggest the people whose step is due ([#70](https://github.com/paulthvt/loomia/issues/70)) ([0f5fc82](https://github.com/paulthvt/loomia/commit/0f5fc82f1f2a721004810388c2afeab80396dd1e))
* **ui:** put field labels above a white bordered box ([#77](https://github.com/paulthvt/loomia/issues/77)) ([e3ba823](https://github.com/paulthvt/loomia/commit/e3ba82364c15ae244c1664b24e6db29bd956be6f))
* workflows — next step, pause, follow with ([#57](https://github.com/paulthvt/loomia/issues/57)) ([#69](https://github.com/paulthvt/loomia/issues/69)) ([33daa99](https://github.com/paulthvt/loomia/commit/33daa9924d0a7ae431c1c63c05e70e1b2d87ac21))
* **workflows:** edit workflows in Settings ([#71](https://github.com/paulthvt/loomia/issues/71)) ([bc37bb4](https://github.com/paulthvt/loomia/commit/bc37bb4f0f9b6cd4f33aa109c06ff899a62e38eb))


### 🐛 Bug Fixes

* **contacts:** delete once the page is off screen on mobile ([#75](https://github.com/paulthvt/loomia/issues/75)) ([409b8d5](https://github.com/paulthvt/loomia/commit/409b8d540d1ffa4ecd9a9b5ab3b8da5241df7771))
* **ui:** align the contact page and shared styles with Figma ([#74](https://github.com/paulthvt/loomia/issues/74)) ([5e6270b](https://github.com/paulthvt/loomia/commit/5e6270be2836fba960e7fa300bb0c8c51fe1467b))


### 📚 Documentation

* add visual identity and design system specification ([#14](https://github.com/paulthvt/loomia/issues/14)) ([0822042](https://github.com/paulthvt/loomia/commit/08220429ed7f3113607df82f0b52e0fe738fe76b))
* design for contacts, stages and workflows ([#62](https://github.com/paulthvt/loomia/issues/62)) ([0084dff](https://github.com/paulthvt/loomia/commit/0084dff6924dac3fea3bdf2d71d3041ade18b24b))
* track work on the project board and require a ticket in PRs ([#20](https://github.com/paulthvt/loomia/issues/20)) ([1ae59fe](https://github.com/paulthvt/loomia/commit/1ae59fe9d667b2d635630fbacf9852a0444d0d5c))


### ✅ Tests

* golden tests for every widget preview ([#42](https://github.com/paulthvt/loomia/issues/42)) ([905afa9](https://github.com/paulthvt/loomia/commit/905afa9495512ae7b77aaa410e70e78d95e1c47a))


### 🔄 CI/CD

* add CI and release-please workflows ([#2](https://github.com/paulthvt/loomia/issues/2)) ([aa6dcd8](https://github.com/paulthvt/loomia/commit/aa6dcd8b952bd2647f66416c107713b884acd664))
* sign Android releases and ship them to Play internal testing ([#44](https://github.com/paulthvt/loomia/issues/44)) ([589cf8c](https://github.com/paulthvt/loomia/commit/589cf8c778468b529054b1de57b7c2659f7c2854))


### 🔧 Miscellaneous

* add renovate configuration ([#3](https://github.com/paulthvt/loomia/issues/3)) ([ac99639](https://github.com/paulthvt/loomia/commit/ac996394a297360b3a2ef8796c85991f10a0e17b))
* **brand:** Play Store icon and feature graphic ([#99](https://github.com/paulthvt/loomia/issues/99)) ([39edbfc](https://github.com/paulthvt/loomia/commit/39edbfc72a97c05ca266e1938b7cc79bda041769))
* **deps:** lock file maintenance ([#51](https://github.com/paulthvt/loomia/issues/51)) ([56f49b2](https://github.com/paulthvt/loomia/commit/56f49b2d4416e095f754faa2cb340525021704a0))
* **deps:** move to the standalone material_ui package ([#40](https://github.com/paulthvt/loomia/issues/40)) ([ee47eb4](https://github.com/paulthvt/loomia/commit/ee47eb43c142d6d23ea729e9cbd1e8087ea9372a))
* **deps:** pin dependencies ([#8](https://github.com/paulthvt/loomia/issues/8)) ([c39ff13](https://github.com/paulthvt/loomia/commit/c39ff132539e8089ab790d2217051039b593f10d))
* **deps:** update dependency flutter to v3.47.5 ([#9](https://github.com/paulthvt/loomia/issues/9)) ([4bd5dc1](https://github.com/paulthvt/loomia/commit/4bd5dc1b2db2de273e8c24dca3e84cf0cbe4e37a))
* **deps:** update github actions (major) ([#45](https://github.com/paulthvt/loomia/issues/45)) ([16d4c27](https://github.com/paulthvt/loomia/commit/16d4c27c7b54113d92d0d9eda162765526641451))
* **deps:** update gradle to v9.8.0 ([#12](https://github.com/paulthvt/loomia/issues/12)) ([b3297a7](https://github.com/paulthvt/loomia/commit/b3297a7e6c3864278eb00a2f29b5941624f7d3ae))
* **deps:** update plugin com.android.application to v9.4.1 ([#13](https://github.com/paulthvt/loomia/issues/13)) ([4d73855](https://github.com/paulthvt/loomia/commit/4d73855a2bdd2d3b39162b440593c207b7c443f7))
* **deps:** update plugin org.jetbrains.kotlin.android to v2.4.20 ([#11](https://github.com/paulthvt/loomia/issues/11)) ([1137772](https://github.com/paulthvt/loomia/commit/1137772561aa5e8a08122d21b10f3332ced56569))
* drop the renovate schedule ([#5](https://github.com/paulthvt/loomia/issues/5)) ([afcaeaf](https://github.com/paulthvt/loomia/commit/afcaeaf425298e36dbfaf4bb39b12c3e2164b2d8))
* initialize Flutter project foundation ([07a759f](https://github.com/paulthvt/loomia/commit/07a759f76414731e7220a62aebdd99e1a09c55f4))
* **l10n:** sync translations ([#27](https://github.com/paulthvt/loomia/issues/27)) ([eda8edf](https://github.com/paulthvt/loomia/commit/eda8edf1cc135a7576880cc986992146cfef38ef))
* **l10n:** sync translations ([#35](https://github.com/paulthvt/loomia/issues/35)) ([400c74e](https://github.com/paulthvt/loomia/commit/400c74e3231ae8885ef6c2de99b84c7f0b899d5c))
* **l10n:** sync translations ([#52](https://github.com/paulthvt/loomia/issues/52)) ([5a14445](https://github.com/paulthvt/loomia/commit/5a1444597cde890cdf9603e6c98bf301cb1b7ec3))
* **l10n:** sync translations ([#85](https://github.com/paulthvt/loomia/issues/85)) ([94bb4b2](https://github.com/paulthvt/loomia/commit/94bb4b20013256f7c9c13db0139aa615584787dc))
* **l10n:** translate with Gemini instead of Tolgee ([#93](https://github.com/paulthvt/loomia/issues/93)) ([ab497e0](https://github.com/paulthvt/loomia/commit/ab497e0572d15643fe15db1fae4f8efd49414c6a))
* loomia project id and repo links ([#89](https://github.com/paulthvt/loomia/issues/89)) ([0018f6b](https://github.com/paulthvt/loomia/commit/0018f6be5548bd546990ebc5bedd9d58cf8736bb))
* rename Folo to Loomia in code, ids and copy ([#86](https://github.com/paulthvt/loomia/issues/86)) ([60287c2](https://github.com/paulthvt/loomia/commit/60287c29fbb3ec44e9a51cc15d589e92b9d2cf9b))
* report uncaught errors from release builds to Sentry ([#50](https://github.com/paulthvt/loomia/issues/50)) ([450f3e3](https://github.com/paulthvt/loomia/commit/450f3e37527b2608ea129471568085c9fd56bc98))
* **supabase:** disable TOTP MFA, document the Twilio diff ([#32](https://github.com/paulthvt/loomia/issues/32)) ([22dac01](https://github.com/paulthvt/loomia/commit/22dac013cd15ff45b57f876398ad16091d8263ef))
* **supabase:** manage project config and migrations from the repo ([#30](https://github.com/paulthvt/loomia/issues/30)) ([8b71552](https://github.com/paulthvt/loomia/commit/8b7155244b4ddcb8527731651ab2d008550c4782))
* track shared Claude Code settings, ignore local ones ([#16](https://github.com/paulthvt/loomia/issues/16)) ([a74f3c1](https://github.com/paulthvt/loomia/commit/a74f3c1402744d83330ac05bb12953f5ccf41011))
