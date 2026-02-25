package bank

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/bank"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestBankPrecompileTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.BankPrecompileApp](integration.CreateEvmd, "evm.BankPrecompileApp")
	s := bank.NewPrecompileTestSuite(create)
	suite.Run(t, s)
}

func TestBankPrecompileIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.BankPrecompileApp](integration.CreateEvmd, "evm.BankPrecompileApp")
	bank.TestIntegrationSuite(t, create)
}
