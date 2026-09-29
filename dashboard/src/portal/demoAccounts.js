// Demo credentials shown (and pre-filled) on the portal login so evaluators
// can explore every role with one click. The backend creates the worker and
// admin accounts on startup (backend/app/services/demo_accounts.py - keep the
// two in sync); any phone number works for citizens with OTP 123456.
export const DEMO_ACCOUNTS = {
  citizen: { phone: '9876543210', otp: '123456' },
  worker: { empId: 'DEMO-WORKER', password: 'Demo@123' },
  admin: { empId: 'DEMO-ADMIN', password: 'Demo@123' },
};
