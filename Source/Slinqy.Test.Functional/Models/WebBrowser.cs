﻿namespace Slinqy.Test.Functional.Models
{
    using System;
    using System.Collections.Generic;
    using System.Globalization;
    using System.Linq;
    using System.Reflection;
    using System.Threading;
    using OpenQA.Selenium;

    /// <summary>
    /// Models a web browser.
    /// </summary>
    public sealed class WebBrowser : IDisposable
    {
        /// <summary>
        /// Defines the name of constant field that each class inheriting Webpage must implement.
        /// </summary>
        private const string WebPageRelativePathConstantName = "RelativePath";

        /// <summary>
        /// Maintains the collection of classes inheriting the Webpage class, keyed on their RelativePaths.
        /// This is done so that instances of these types can be instantiated from a given relative path.
        /// </summary>
        private static readonly Dictionary<Uri, Type> WellKnownPages = GetWellKnownPages();

        /// <summary>
        /// Reference to the IWebDriver to use for controlling the browser.
        /// </summary>
        private readonly IWebDriver webBrowserDriver;

        /// <summary>
        /// The default base URI of the target website, will be used with relative paths.
        /// </summary>
        private readonly Uri        baseUri;

        /// <summary>
        /// Initializes a new instance of the <see cref="WebBrowser"/> class.
        /// </summary>
        /// <param name="webBrowserDriver">Specifies the IWebDriver instance to use for interacting with the browser.</param>
        /// <param name="baseUri">Specifies the base URI that will be used with all relative paths.</param>
        public
        WebBrowser(
            IWebDriver  webBrowserDriver,
            Uri         baseUri)
        {
            this.baseUri          = baseUri;
            this.webBrowserDriver = webBrowserDriver;
        }

        /// <summary>
        /// Directs the browser to navigate directly to the specified TPage,
        /// as if the user typed the URL directly in the browsers address bar.
        /// </summary>
        /// <typeparam name="TPage">
        /// Specifies the well known Webpage to navigate to.
        /// The address of the Webpage will be generated by combining the Base URI and the RelativePath constant of the inheriting Webpage class.
        /// </typeparam>
        /// <returns>
        /// Returns an instance of Webpage that represents the current web page.
        /// Remember that it is possible to end up on a web page that is different than what was requested by TPage.
        /// </returns>
        public
        TPage
        NavigateTo<TPage>()
            where TPage : Webpage
        {
            var relativeUri = WellKnownPages.Single(pair => pair.Value == typeof(TPage)).Key;

            var fullyQualifiedUri = new Uri(
                this.baseUri,
                relativeUri);

            this.webBrowserDriver
                .Navigate()
                .GoToUrl(fullyQualifiedUri);

            return this.GetCurrentPageAs<TPage>();
        }

        /// <summary>
        /// Attempts to get an instance of the current Webpage as the specified TPage type.
        /// </summary>
        /// <typeparam name="TPage">Specifies the type of Webpage that is expected.</typeparam>
        /// <returns>
        /// If the current Webpage is of type TPage, then an instance of Webpage modeling TPage will be returned.
        /// Otherwise, null will be returned.
        /// </returns>
        public
        TPage
        GetCurrentPageAs<TPage>()
            where TPage : Webpage
        {
            var uri = new Uri(this.webBrowserDriver.Url);
            var path = uri.AbsolutePath;

            var match = WellKnownPages.FirstOrDefault(kvp => kvp.Key.OriginalString == path);

            if (match.Key == null)
                throw new NotFoundException("Could not find a matching page for path " + path);

            var pageType = match.Value;

            return (TPage)Activator.CreateInstance(pageType, this.webBrowserDriver);
        }

        /// <summary>
        /// Frees any resources allocated by this instance.
        /// </summary>
        public
        void
        Dispose()
        {
            this.webBrowserDriver.Dispose();
        }

        /// <summary>
        /// Returns a collection of all the classes in all the loaded assemblies that inherit from the Webpage class.
        /// </summary>
        /// <returns>Returns a collection of Types, keyed on the relative path of the Webpage.</returns>
        private
        static
        Dictionary<Uri, Type>
        GetWellKnownPages()
        {
            var types = Assembly
                .GetExecutingAssembly()
                .GetTypes();

            var wellKnownPages = new Dictionary<Uri, Type>();

            foreach (var type in types.Where(t => typeof(Webpage).IsAssignableFrom(t) && !t.IsAbstract))
            {
                var relativePathField = type
                    .GetFields(BindingFlags.Public | BindingFlags.Static)
                    .SingleOrDefault(fi =>
                        fi.IsLiteral &&
                        !fi.IsInitOnly &&
                        fi.Name == WebPageRelativePathConstantName);

                if (relativePathField == null) {
                    throw new InvalidOperationException(
                        string.Format(
                            CultureInfo.InvariantCulture,
                            "You must add a public string constant named {0} to type {1} before it can be used.",
                            WebPageRelativePathConstantName,
                            type.FullName));
                }

                wellKnownPages.Add(
                    new Uri(relativePathField.GetRawConstantValue().ToString(), UriKind.Relative),
                    type);
            }

            return wellKnownPages;
        }
    }
}