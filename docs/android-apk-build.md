# Build the SAIF.NET Android APK

1. Open **Actions** in the GitHub repository.
2. Select **SAIF.NET Android APK**.
3. Press **Run workflow** and select the feature branch you want to build.
4. Wait for regression tests and the debug APK build to complete.
5. Open the completed run and download the artifact named `saif-net-router-manager-debug-apk`.

The workflow creates Android platform scaffolding on the temporary GitHub runner if the repository does not contain an `android/` directory. It does not commit generated files back to the repository. The output is a **debug APK for testing**, not a signed production release.

Do not install an APK from a failed or untrusted run. Before a production release, add a protected signing process using repository secrets or a secure signing service, review permissions, and test on supported Android devices.
