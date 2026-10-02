function showAuthMessage(message) {
  const messageElement = document.getElementById('auth-message');
  if (messageElement) messageElement.textContent = message;
}

function getSupabase() {
  if (!window.appSupabase) {
    showAuthMessage('Could not connect to Supabase. Check your connection and client setup.');
    return null;
  }
  return window.appSupabase;
}

const loginForm = document.getElementById('Login-form');
if (loginForm) {
  loginForm.addEventListener('submit', async function (event) {
    event.preventDefault();
    showAuthMessage('Signing in…');

    const client = getSupabase();
    if (!client) return;

    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const { data, error } = await client.auth.signInWithPassword({ email, password });

    if (error) {
      showAuthMessage(error.message);
      return;
    }

    const { data: profile, error: profileError } = await client
      .from('profiles')
      .select('username')
      .eq('id', data.user.id)
      .single();

    if (profileError || !profile) {
      showAuthMessage('Signed in, but no profile was found. Re-run the updated Supabase setup SQL.');
      return;
    }

    // Keep the display name available to pages that have not yet been moved off local storage.
    localStorage.setItem('currentUser', profile.username);
    window.location.href = 'homepage.html';
  });
}

const signupForm = document.getElementById('Signup-form');
if (signupForm) {
  signupForm.addEventListener('submit', async function (event) {
    event.preventDefault();
    showAuthMessage('Creating account…');

    const client = getSupabase();
    if (!client) return;

    const username = document.getElementById('username').value.trim();
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    if (username.length < 4 || username.length > 10) {
      showAuthMessage('Username must be 4–10 characters.');
      return;
    }

    const { data, error } = await client.auth.signUp({
      email,
      password,
      options: { data: { username } }
    });

    if (error) {
      showAuthMessage(error.message);
      return;
    }

    if (data.session) {
      localStorage.setItem('currentUser', username);
      window.location.href = 'homepage.html';
      return;
    }

    showAuthMessage('Account created. Check your email to confirm your address, then log in.');
    signupForm.reset();
  });
}
