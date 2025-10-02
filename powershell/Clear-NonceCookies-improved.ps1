# .SYNOPSIS
#   Attempts to expire OpenIdConnect.nonce cookies for Microsoft login endpoints.

# .DESCRIPTION
#   This script provides a more pragmatic approach by using WinInet's InternetSetCookie
#   to set expired cookies for a given domain and cookie-name prefix. Note:
#   - This acts on the WinINET cookie store (IE / legacy Edge contexts and some system-level stores),
#     and may not affect modern Chromium-based browser profiles.
#   - Use with caution. Test in a non-production user profile first.
#>

param (
    [string]$Domain = "login.microsoftonline.com",
    [string]$CookiePrefix = "OpenIdConnect.nonce"
)

# Add minimal P/Invoke for InternetSetCookie (wininet.dll)
$member = @"
using System;
using System.Runtime.InteropServices;
public static class WinInet {
    [DllImport("wininet.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool InternetSetCookie(string lpszUrlName, string lpszCookieName, string lpszCookieData);
}
"@

Add-Type -TypeDefinition $member -ErrorAction Stop

function Set-ExpiredCookie {
    param (
        [string]$Url,
        [string]$CookieName
    )

    # Build cookie string with a past expiration date
    $cookieData = "deleted=true; expires=Thu, 01-Jan-1970 00:00:00 GMT; path=/"
    $ok = [WinInet]::InternetSetCookie($Url, $CookieName, $cookieData)
    if ($ok) {
        Write-Output "Expired cookie: $CookieName on $Url"
    } else {
        $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Warning "Failed to set expired cookie for $CookieName on $Url (win32 error $err)"
    }
}

# Try to expire cookies following the prefix pattern
# Common forms: OpenIdConnect.nonce, OpenIdConnect.nonce.xyz...
$baseUrl = "https://$Domain/"

# Best-effort: attempt common suffix patterns
for ($i=0; $i -le 10; $i++) {
    $suffix = if ($i -eq 0) { "" } else { ".$i" }
    $candidate = "${CookiePrefix}${suffix}"
    Set-ExpiredCookie -Url $baseUrl -CookieName $candidate
}

Write-Output "WinInet-based expiration attempts complete. Note: modern Chromium browsers store cookies in profile DBs and may require browser profile cleanup or targeted automation to remove."