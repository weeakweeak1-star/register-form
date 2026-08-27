'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "d91d5c0ec3d14eeda90ea45c30dc5814",
".git/config": "35496b839f7e1624bdf4ff7814dae46c",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "5ab7a4355e4c959b0c5c008f202f51ec",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "e0b5b08e209fa15f48d796e8976bc42b",
".git/hooks/fsmonitor-watchman.sample": "5c90c1740b0cacecb469934e16fe8cb6",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "b1b4c3104e2caf56ef81918c36a8bf04",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "2c04b3d870815afc5f8c6e1fd3535eb8",
".git/logs/refs/heads/gh-pages": "b64fa8f806a9dfefecea18fdae09bc4a",
".git/logs/refs/remotes/origin/gh-pages": "0966f271e4bda5fc1f9b91803a92ceb5",
".git/objects/03/2fe904174b32b7135766696dd37e9a95c1b4fd": "80ba3eb567ab1b2327a13096a62dd17e",
".git/objects/03/eaddffb9c0e55fb7b5f9b378d9134d8d75dd37": "87850ce0a3dd72f458581004b58ac0d6",
".git/objects/05/19f8cfafd0a2f1d1e178c4a67d33a706356cb3": "3c856e5c86745003d146c97112dfb6ec",
".git/objects/0a/7bb33acefcf9a3c37d6d00e3f8eec74b000c43": "e3b35fda7d481d22226fdd2423781bc2",
".git/objects/0b/5314aeb5448547238de59510faec7f6bab81b8": "ce79d1b618004df78bcae340a8699a07",
".git/objects/0e/f704e16830ecd04cffe8f2f7fb5360a65c3acc": "56f8bac4bbd6154abc82cc2e87c862f5",
".git/objects/11/3ca00eb4d7d898d6bc3afe643d05a11fa4bec6": "9b2567273a714e4e06a5dc372323556d",
".git/objects/17/db60d8b681e40c542dc70475e7fc8c1b8ca2ae": "564a942d5796f1aee35fd426982ea2f5",
".git/objects/27/47f371e27a1f80c01ed2b08eb7c9df0711564d": "9b2303a435feeaa87909ed6a09d9764a",
".git/objects/27/98bc5e4ebcb0cb4059e8de727b8f01b9160a2d": "8ca2abfd95771743cf576cdaa03b2d91",
".git/objects/2c/8c7e114bf9776a2f8154a3de42eb42a05139a6": "7bff854a2c1c5a562e036af45bca6cbc",
".git/objects/2e/6f1f235675d8d0c612ad771dfb6a9c71dc4edd": "4f02e446104b5a05e9dcd9dd5ed37a56",
".git/objects/2f/e93742439e2a704890decbdb414da52aa4e246": "02165ffa0ba8d537586e5f0280e06f73",
".git/objects/32/a1efaa9e0914d35f6444d657943138f033f15b": "905d643d1404214a5bdafa992288c436",
".git/objects/33/31d9290f04df89cea3fb794306a371fcca1cd9": "e54527b2478950463abbc6b22442144e",
".git/objects/33/7a9cca43621302bb0b243cb043936bc7543c89": "a05c701b5308e7b207d601699aea6ce7",
".git/objects/34/cadeb4f9213e9c3f7ee79d0e0654cec9eaa2da": "28a9ca564dfdd4deba6ca9e79ecfd385",
".git/objects/35/96d08a5b8c249a9ff1eb36682aee2a23e61bac": "e931dda039902c600d4ba7d954ff090f",
".git/objects/40/1184f2840fcfb39ffde5f2f82fe5957c37d6fa": "1ea653b99fd29cd15fcc068857a1dbb2",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/4a/c7fccd6fd33c5402246518e2244ada2da4d1a7": "05a629f99de487ce8c0803b24ab7ef60",
".git/objects/4f/02e9875cb698379e68a23ba5d25625e0e2e4bc": "254bc336602c9480c293f5f1c64bb4c7",
".git/objects/57/7946daf6467a3f0a883583abfb8f1e57c86b54": "846aff8094feabe0db132052fd10f62a",
".git/objects/5e/6d258682a54b59cc9ce11915e05219cbf47785": "715f574597aa389bd07f585014ec11fb",
".git/objects/5f/bf1f5ee49ba64ffa8e24e19c0231e22add1631": "f19d414bb2afb15ab9eb762fd11311d6",
".git/objects/64/5116c20530a7bd227658a3c51e004a3f0aefab": "f10b5403684ce7848d8165b3d1d5bbbe",
".git/objects/67/98865dea997afcfda395925958a3226ecf20ee": "d5468b5bcecc50d32d28bbcbcb6ed714",
".git/objects/69/dd618354fa4dade8a26e0fd18f5e87dd079236": "8cc17911af57a5f6dc0b9ee255bb1a93",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/6c/06cc512797cf57a1358a6c4b9aaeb1ec258824": "34a53e8878d87137bb4095227f1c413a",
".git/objects/71/11cf584aa8e7f09504a23aed5afde647046889": "26c9701f0358625fa0249a135761056d",
".git/objects/73/83069290ae3db45857dedd324469c5e51f4d01": "44d1d128aee5e4c6eae5afea9b77d635",
".git/objects/75/07b6c076325c91d843f5ecc372aa8f3cb216b1": "71a05621cc12f377697aa3188ba8be48",
".git/objects/76/20fbac260941e4485df2779d7f52c77702834f": "8cf5abad602f0c60df3d1bba899059d3",
".git/objects/80/1f832cb56e272c1c2e6c60cb221418ffc05b3b": "2ba1a0f60675c0884f086e80a7d27388",
".git/objects/80/fbb094b2d6028b618369fc132794172449f5a6": "e89b4a797c61ebe967440458424ecaf8",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/51a9b155d31c44b148d7e287fc2872e0cafd42": "9f785032380d7569e69b3d17172f64e8",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/8a/ac4fa25c56f3a0518a7599895c9ba44db6dc44": "d196f16d06538c744b26e0b8d3aaafa4",
".git/objects/8e/f8650508a33ad2ec4a11bd5dd8bff031b16ee6": "55d0e56bade5011c9cc289aca14c0d91",
".git/objects/8f/e7af5a3e840b75b70e59c3ffda1b58e84a5a1c": "e3695ae5742d7e56a9c696f82745288d",
".git/objects/91/4a40ccb508c126fa995820d01ea15c69bb95f7": "8963a99a625c47f6cd41ba314ebd2488",
".git/objects/93/bdc2053791193672fa335bbf14f044e71b7eea": "bd726e99fc0cf77b6baf7f8733f89540",
".git/objects/9a/f9386eed9f45baa0ab0dc4ab0af4167c06b409": "01b05c541ed78a3a227a60dd320bb152",
".git/objects/9c/ce9ad09a4caeda215981acf7b7b4060ed30de1": "ea55609c7e70a624af89de29729a487b",
".git/objects/9c/d65c0709a38ff19b274091e6ba4e62f5e11b82": "503e404286743b94541906f22a634bd8",
".git/objects/9d/cc84a4caabbab2b6ef8e0d5670801112789475": "544c5f3d6ee96b30a3c7103fe3e6949e",
".git/objects/a1/fedf69b8ed11de3952063d0f4b60acd8595d0e": "ac7083e0356719133df35637c9e99d00",
".git/objects/a5/de584f4d25ef8aace1c5a0c190c3b31639895b": "9fbbb0db1824af504c56e5d959e1cdff",
".git/objects/a8/8c9340e408fca6e68e2d6cd8363dccc2bd8642": "11e9d76ebfeb0c92c8dff256819c0796",
".git/objects/b2/1f38a59c6008b5d5cb9ac4f9e93c9a746688f2": "c15f81bfc0fdc68fa2ac65f3eb3ad711",
".git/objects/b5/c1d0f5f6df93a8a59d2455c4380d201575c51d": "1a7366a0420153100d6029b7b3ebc5fd",
".git/objects/b6/ce0da819719e7d5fafa9e7b528a6a8dfd985a6": "047821b85a7cffbffe78515b7d33535b",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/bb/4fa2400c94634547e7f0c1671eb5ed50030e2c": "417e6f919b5a6a372ba2eced65fc5992",
".git/objects/be/97998d6c0c7e383326d633d2a884ded30d8af7": "4065eb69cca75af0ed2aba4e7c02ab34",
".git/objects/c2/cc918eda303878c106df8d5e7cfaca77545a45": "0dcaacb06db044272689cdc3434aee30",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/d9/3952e90f26e65356f31c60fc394efb26313167": "1401847c6f090e48e83740a00be1c303",
".git/objects/dd/1be19bf5b8b572ecb665cfb5c8199b4068d7c3": "43a6dc091a991d0352bec1ef4653375f",
".git/objects/e6/b452bcc981e6bdcab0ca101a49431ffbeaa5fb": "22c7f00da33f26887951dc5736a1769f",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/ea/a0b0afd121031f9bf6f7f085c0342bd2930f4b": "bbd93cadeef7b665514cf9241dbb3438",
".git/objects/ea/a111a29b05066aa970c85c080bc7121347f2f2": "31ecae49cf285b0ef2dec96d3a43ca9c",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/ef/b875788e4094f6091d9caa43e35c77640aaf21": "27e32738aea45acd66b98d36fc9fc9e0",
".git/objects/f2/04823a42f2d890f945f70d88b8e2d921c6ae26": "6b47f314ffc35cf6a1ced3208ecc857d",
".git/objects/f3/709a83aedf1f03d6e04459831b12355a9b9ef1": "538d2edfa707ca92ed0b867d6c3903d1",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/fc/6033b6b90334f0ad730c3dd4d93bea9253cf2b": "8ced577ec663982958a6cc8fa1b0f772",
".git/refs/heads/gh-pages": "bceea2413334b59011183737ec039445",
".git/refs/remotes/origin/gh-pages": "cbc7e0a0a8848423416a46f0a729a4f2",
"assets/AssetManifest.bin": "693635b5258fe5f1cda720cf224f158c",
"assets/AssetManifest.bin.json": "69a99f98c8b1fb8111c5fb961769fcd8",
"assets/AssetManifest.json": "2efbb41d7877d10aac9d091f58ccd7b9",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "a9b78269efd7367c3ff382c1f561acfc",
"assets/NOTICES": "cdf8fbe78b571e0dc75c7f56646d328b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "86e461cf471c1640fd2b461ece4589df",
"canvaskit/canvaskit.js.symbols": "68eb703b9a609baef8ee0e413b442f33",
"canvaskit/canvaskit.wasm": "efeeba7dcc952dae57870d4df3111fad",
"canvaskit/chromium/canvaskit.js": "34beda9f39eb7d992d46125ca868dc61",
"canvaskit/chromium/canvaskit.js.symbols": "5a23598a2a8efd18ec3b60de5d28af8f",
"canvaskit/chromium/canvaskit.wasm": "64a386c87532ae52ae041d18a32a3635",
"canvaskit/skwasm.js": "f2ad9363618c5f62e813740099a80e63",
"canvaskit/skwasm.js.symbols": "80806576fa1056b43dd6d0b445b4b6f7",
"canvaskit/skwasm.wasm": "f0dfd99007f989368db17c9abeed5a49",
"canvaskit/skwasm_st.js": "d1326ceef381ad382ab492ba5d96f04d",
"canvaskit/skwasm_st.js.symbols": "c7e7aac7cd8b612defd62b43e3050bdd",
"canvaskit/skwasm_st.wasm": "56c3973560dfcbf28ce47cebe40f3206",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "76f08d47ff9f5715220992f993002504",
"flutter_bootstrap.js": "b3deae4eb3c3910edfc122117a920647",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "49646672584de6a9d45672decb3e8604",
"/": "49646672584de6a9d45672decb3e8604",
"main.dart.js": "990b263ce2481635a194ff15297b3952",
"manifest.json": "c0f721faab11283ffa33fa20be1a3a57",
"version.json": "881034809d1ff5182cfce712eaa71283"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
