// Firebase ID token verification middleware
// Replace with real firebase-admin verification in production
const verifyFirebaseToken = async (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }
  const token = auth.split(' ')[1];
  // In production: await admin.auth().verifyIdToken(token)
  // Demo: decode mock token
  if (!token || token.length < 10) {
    return res.status(401).json({ error: 'Invalid token' });
  }
  req.user = { uid: `user_${token.slice(0, 8)}` };
  next();
};

module.exports = { verifyFirebaseToken };
