import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iamport_webview_flutter/iamport_webview_flutter.dart' as iawf;
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webviewx/src/controller/impl/mobile.dart';
import 'package:webviewx/src/controller/interface.dart' as ctrl_interface;
import 'package:webviewx/src/utils/utils.dart';
import 'package:webviewx/src/view/interface.dart' as view_interface;

/// Mobile implementation
class WebViewX extends StatefulWidget implements view_interface.WebViewX {
  /// Initial content
  @override
  final String initialContent;

  /// Initial source type. Must match [initialContent]'s type.
  ///
  /// Example:
  /// If you set [initialContent] to '<p>hi</p>', then you should
  /// also set the [initialSourceType] accordingly, that is [SourceType.html].
  @override
  final SourceType initialSourceType;

  /// User-agent
  /// On web, this is only used when using [SourceType.urlBypass]
  @override
  final String? userAgent;

  /// Widget width
  @override
  final double width;

  /// Widget height
  @override
  final double height;

  /// Callback which returns a referrence to the [WebViewXController]
  /// being created.
  @override
  final Function(ctrl_interface.WebViewXController controller)?
      onWebViewCreated;

  /// A set of [EmbeddedJsContent].
  ///
  /// You can define JS functions, which will be embedded into
  /// the HTML source (won't do anything on URL) and you can later call them
  /// using the controller.
  ///
  /// For more info, see [EmbeddedJsContent].
  @override
  final Set<EmbeddedJsContent> jsContent;

  /// A set of [DartCallback].
  ///
  /// You can define Dart functions, which can be called from the JS side.
  ///
  /// For more info, see [DartCallback].
  @override
  final Set<DartCallback> dartCallBacks;

  /// Boolean value to specify if should ignore all gestures that touch the webview.
  ///
  /// You can change this later from the controller.
  @override
  final bool ignoreAllGestures;

  /// Boolean value to specify if Javascript execution should be allowed inside the webview
  @override
  final JavascriptMode javascriptMode;

  /// This defines if media content(audio - video) should
  /// auto play when entering the page.
  @override
  final AutoMediaPlaybackPolicy initialMediaPlaybackPolicy;

  /// Callback for when the page starts loading.
  @override
  final void Function(String src)? onPageStarted;

  /// Callback for when the page has finished loading (i.e. is shown on screen).
  @override
  final void Function(String src)? onPageFinished;

  /// Callback to decide whether to allow navigation to the incoming url
  @override
  final NavigationDelegate? navigationDelegate;

  /// Callback for when something goes wrong in while page or resources load.
  @override
  final void Function(WebResourceError error)? onWebResourceError;

  /// Parameters specific to the web version.
  /// This may eventually be merged with [mobileSpecificParams],
  /// if all features become cross platform.
  @override
  final WebSpecificParams webSpecificParams;

  /// Parameters specific to the web version.
  /// This may eventually be merged with [webSpecificParams],
  /// if all features become cross platform.
  @override
  final MobileSpecificParams mobileSpecificParams;

  /// Constructor
  const WebViewX({
    super.key,
    this.initialContent = 'about:blank',
    this.initialSourceType = SourceType.url,
    this.userAgent,
    required this.width,
    required this.height,
    this.onWebViewCreated,
    this.jsContent = const {},
    this.dartCallBacks = const {},
    this.ignoreAllGestures = false,
    this.javascriptMode = JavascriptMode.unrestricted,
    this.initialMediaPlaybackPolicy =
        AutoMediaPlaybackPolicy.requireUserActionForAllMediaTypes,
    this.onPageStarted,
    this.onPageFinished,
    this.navigationDelegate,
    this.onWebResourceError,
    this.webSpecificParams = const WebSpecificParams(),
    this.mobileSpecificParams = const MobileSpecificParams(),
  });

  @override
  WebViewXState createState() => WebViewXState();
}

class WebViewXState extends State<WebViewX> {
  late iawf.WebViewController originalWebViewController;
  late WebViewXController webViewXController;

  late bool _ignoreAllGestures;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid &&
        widget.mobileSpecificParams.androidEnableHybridComposition) {
      iawf.WebView.platform = iawf.SurfaceAndroidWebView();
    }

    _ignoreAllGestures = widget.ignoreAllGestures;
    webViewXController = _createWebViewXController();
  }

  void mockMethod(WebResourceError error) {}

  iawf.WebResourceErrorCallback? onWebResourceError;
  iawf.NavigationDelegate? navigationDelegate;

  @override
  Widget build(BuildContext context) {
    final javascriptMode = widget.javascriptMode == JavascriptMode.unrestricted
        ? iawf.JavascriptMode.unrestricted
        : iawf.JavascriptMode.disabled;

    final initialMediaPlaybackPolicy = widget.initialMediaPlaybackPolicy ==
            AutoMediaPlaybackPolicy.alwaysAllow
        ? iawf.AutoMediaPlaybackPolicy.always_allow
        : iawf.AutoMediaPlaybackPolicy.require_user_action_for_all_media_types;

    onWebResourceError = (err) {
      WebResourceErrorType? errorType;
      try {
        errorType = WebResourceErrorType.values.singleWhere(
              (value) => value.toString() == err.errorType.toString(),
        );
      } catch (error) {
        errorType = null;
      }
      widget.onWebResourceError?.call(
        WebResourceError(
          description: err.description,
          errorCode: err.errorCode,
          domain: err.domain,
          errorType: errorType,
          failingUrl: err.failingUrl,
        ),
      );
    };

    navigationDelegate = (request) async {
      if (widget.navigationDelegate == null) {
        webViewXController.value =
            webViewXController.value.copyWith(source: request.url);
        return iawf.NavigationDecision.navigate;
      }

      final delegate = await widget.navigationDelegate!.call(
        NavigationRequest(
          content: NavigationContent(
            request.url,
            webViewXController.value.sourceType,
          ),
          isForMainFrame: request.isForMainFrame,
        ),
      );

      switch (delegate) {
        case NavigationDecision.navigate:
          // When clicking on an URL, the sourceType stays the same.
          // That's because you cannot move from URL to HTML just by clicking.
          // Also we don't take URL_BYPASS into consideration because it has no effect here in mobile
          webViewXController.value = webViewXController.value.copyWith(
            source: request.url,
          );
          return iawf.NavigationDecision.navigate;
        case NavigationDecision.prevent:
          return iawf.NavigationDecision.prevent;
      }
    };

    void onWebViewCreated(iawf.WebViewController webViewController) {
      originalWebViewController = webViewController;

      webViewXController.connector = originalWebViewController;
      // Calls onWebViewCreated to pass the refference upstream
      if (widget.onWebViewCreated != null) {
        widget.onWebViewCreated?.call(webViewXController);
      }
    }

    final javascriptChannels = widget.dartCallBacks
        .map(
          (cb) => iawf.JavascriptChannel(
            name: cb.name,
            onMessageReceived: (msg) => cb.callBack(msg.message),
          ),
        )
        .toSet();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IgnorePointer(
        ignoring: _ignoreAllGestures,
        child: iawf.WebView(
          key: widget.key,
          initialUrl: _initialContent(),
          javascriptMode: javascriptMode,
          onWebViewCreated: onWebViewCreated,
          javascriptChannels: javascriptChannels,
          gestureRecognizers:
              widget.mobileSpecificParams.mobileGestureRecognizers,
          onPageStarted: widget.onPageStarted,
          onPageFinished: widget.onPageFinished,
          initialMediaPlaybackPolicy: initialMediaPlaybackPolicy,
          onWebResourceError: onWebResourceError,
          gestureNavigationEnabled:
              widget.mobileSpecificParams.gestureNavigationEnabled,
          debuggingEnabled: widget.mobileSpecificParams.debuggingEnabled,
          navigationDelegate: navigationDelegate,
          userAgent: widget.userAgent,
        ),
      ),
    );
  }

  // Returns initial data
  String? _initialContent() {
    if (widget.initialSourceType == SourceType.html) {
      return HtmlUtils().preprocessSource(
        widget.initialContent,
        jsContent: widget.jsContent,
        encodeHtml: true,
      );
    }
    return widget.initialContent;
  }

  // Creates a WebViewXController and adds the listener
  WebViewXController _createWebViewXController() {
    return WebViewXController(
      initialContent: widget.initialContent,
      initialSourceType: widget.initialSourceType,
      ignoreAllGestures: _ignoreAllGestures,
    )
      ..addListener(_handleChange)
      ..addIgnoreGesturesListener(_handleIgnoreGesturesChange);
  }

  // Prepares the source depending if it is HTML or URL
  String _prepareContent(WebViewContent model) {
    if (model.sourceType == SourceType.html) {
      return HtmlUtils().preprocessSource(
        model.source,
        jsContent: widget.jsContent,

        // Needed for mobile webview in order to URI-encode the HTML
        encodeHtml: true,
      );
    }
    return model.source;
  }

  // Called when WebViewXController updates it's value
  void _handleChange() {
    final newModel = webViewXController.value;

    originalWebViewController.loadUrl(
      _prepareContent(newModel),
      headers: newModel.headers,
    );
  }

  // Called when the ValueNotifier inside WebViewXController updates it's value
  void _handleIgnoreGesturesChange() {
    setState(() {
      _ignoreAllGestures = webViewXController.ignoresAllGestures;
    });
  }

  @override
  void dispose() {
    webViewXController.removeListener(_handleChange);
    webViewXController.removeIgnoreGesturesListener(
      _handleIgnoreGesturesChange,
    );
    super.dispose();
  }
}
