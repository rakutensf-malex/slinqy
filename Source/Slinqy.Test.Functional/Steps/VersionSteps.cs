namespace Slinqy.Test.Functional.Steps
{
    using System.Reflection;
    using Models;
    using Models.ExampleAppPages;
    using TechTalk.SpecFlow;
    using Xunit;

    /// <summary>
    /// Defines steps for using the versioning infrastructure.
    /// </summary>
    [Binding]
    public class VersionSteps : BaseSteps
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="VersionSteps"/> class.
        /// </summary>
        /// <param name="webBrowser">Specifies the browser.</param>
        public
        VersionSteps(
            WebBrowser webBrowser)
                : base(webBrowser)
        {
        }

        /// <summary>
        /// Verifies that the version number displayed on the web page
        /// footer matches the version number of the local test assembly
        /// ensuring they were both built from the same source code.
        /// </summary>
        [Then]
        public
        void
        ThenTheApplicationVersionMatchesTheTestVersion()
        {
            var examplePage = this.WebBrowser.GetCurrentPageAs<SlinqyExampleWebpage>();

            var websiteVersion = examplePage.Footer.Version;
            var testVersion    = Assembly.GetExecutingAssembly().GetName().Version.ToString();

            Assert.Equal(
                testVersion,
                websiteVersion
            );
        }
    }
}