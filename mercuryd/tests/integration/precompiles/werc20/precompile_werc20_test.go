package werc20

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/werc20"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestWERC20PrecompileUnitTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.WERC20PrecompileApp](integration.CreateEvmd, "evm.WERC20PrecompileApp")
	s := werc20.NewPrecompileUnitTestSuite(create)
	suite.Run(t, s)
}

func TestWERC20PrecompileIntegrationTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.WERC20PrecompileApp](integration.CreateEvmd, "evm.WERC20PrecompileApp")
	werc20.TestPrecompileIntegrationTestSuite(t, create)
}
