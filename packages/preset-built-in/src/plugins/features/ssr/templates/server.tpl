// umi.server.js
import '{{{ RuntimePolyfill }}}';
import { format } from 'url';
import renderServer from '{{{ Renderer }}}';
import { stripBasename, cheerio, handleHTML } from '{{{ Utils }}}';
import { IServerRender } from '@umijs/types';

import { ApplyPluginsType, createMemoryHistory{{ #DynamicImport }}, dynamic{{ /DynamicImport }} } from '{{{ RuntimePath }}}';
import { plugin } from './plugin';

// 主要为后面支持按需服务端渲染，单独用 routes 会全编译
const routes = {{{ Routes }}};

// allow user to extend routes
plugin.applyPlugins({
  key: 'patchRoutes',
  type: ApplyPluginsType.event,
  args: { routes },
});

// origin require module
// https://github.com/webpack/webpack/issues/4175#issuecomment-342931035
const requireFunc = typeof __webpack_require__ === "function" ? __non_webpack_require__ : require;

/**
 * server render function
 * @param params
 */
const render: IServerRender = async (params) => {
  let error;
  const {
    origin = '',
    path,
    htmlTemplate = '',
    mountElementId = '{{{ MountElementId }}}',
    context = {},
    mode = '{{{ Mode }}}',
    basename = '{{{ Basename }}}',
    staticMarkup = {{{ StaticMarkup }}},
    forceInitial = {{{ ForceInitial }}},
    getInitialPropsCtx,
  } = params;
  let manifest = params.manifest;
  const env = '{{{ Env }}}';

  let html = htmlTemplate || {{{ DEFAULT_HTML_PLACEHOLDER }}};
  let rootContainer = '';
  try {
    // handle basename
    const location = stripBasename(basename, `${origin}${path}`);
    const { pathname } = location;
    // server history
    const history = createMemoryHistory({
      initialEntries: [format(location)],
    });
    // for renderServer
    const opts = {
      path,
      history,
      pathname,
      getInitialPropsCtx,
      basename,
      context,
      mode,
      plugin,
      staticMarkup,
      routes,
      isServer: process.env.__IS_SERVER,
    }
    const dynamicImport =  {{{ DynamicImport }}};
    if (dynamicImport && !manifest) {
      try {
        // prerender not work because the manifest generation behind of the prerender
        manifest = requireFunc(`./{{{ ManifestFileName }}}`);
      } catch (_) {}
    }

    // beforeRenderServer hook, for polyfill global.*
    await plugin.applyPlugins({
      key: 'ssr.beforeRenderServer',
      type: ApplyPluginsType.event,
      args: {
        env,
        path,
        context,
        history,
        mode,
        location,
      },
      async: true,
    });

    // renderServer get rootContainer
    const { pageHTML, pageInitialProps, routesMatched } = await renderServer(opts);
    rootContainer = pageHTML;
    if (html) {
      // plugin for modify html template
      html = await plugin.applyPlugins({
        key: 'ssr.modifyServerHTML',
        type: ApplyPluginsType.modify,
        initialValue: html,
        args: {
          context,
          cheerio,
          routesMatched,
          dynamicImport,
          manifest
        },
        async: true,
      });
      html = await handleHTML({ html, rootContainer, pageInitialProps, mountElementId, mode, forceInitial, routesMatched, dynamicImport, manifest });
    }
  } catch (e) {
    // downgrade into csr
    error = e;
  }
  return {
    rootContainer,
    error,
    html,
  }
}

export default render;
